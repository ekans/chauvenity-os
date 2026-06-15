# ADR 0002 — Plain `fr` keymap + `rd.vconsole.keymap` karg for the LUKS boot prompt

Status: Partially superseded by upstream (2026-06-15) — dracut drop-in removed; kargs.d drop-in retained
Date: 2026-05-31
Supersedes: ADR 0001 (extends its mechanism; 0001 fix was incomplete)

## Context

ADR 0001 baked `fr-afnor.map.gz` into the initramfs, assuming the *presence*
of the keymap file was sufficient. That fixed the dracut emergency shell
(`rd.shell`) path — fr-afnor loads there and a manual
`cryptsetup open` unlocks — but the **boot cryptsetup password prompt still
failed**: three `Failed to activate ... (Passphrase incorrect?)` then
`Too many attempts; giving up`.

Long debugging eliminated TPM2/clevis, argon2id KDF, argon2id memory /
RLIMIT_DATA, plymouth, and a systemd ask-password regression (see the
handoff notes). The booted, working deployment was F43 (`43.20260505`,
revision `1bda1a7`); the first failing build was the upstream F43→F44 rebase
(`44.20260512`, first F44 daily `20260517-44`) which pulled
dracut `107→108` + kbd `2.8→2.9` that silently drop keymaps from the
bluefin-dx pre-baked initramfs.

Decisive experiment (2026-05-31): adding kernel arg `rd.vconsole.keymap=fr`
made the F44 boot prompt unlock on the first try with the normal AZERTY
passphrase. The prior karg was `vconsole.keymap=fr-afnor` — it lacked the
`rd.` prefix (so it was not reliably applied inside the initramfs before the
cryptsetup prompt) and used the `afnor` variant.

Two variables changed together: (a) the `rd.` prefix targeting the
initramfs vconsole-setup, and (b) `fr-afnor` → `fr`. They were not isolated
further — the machine boots, KISS. Empirically, plain `fr` driven by
`rd.vconsole.keymap` reliably unlocks; `fr-afnor` driven by plain
`vconsole.keymap` did not.

## Decision

1. Bake `fr.map.gz` (not `fr-afnor.map.gz`) into the initramfs via the dracut
   drop-in `/usr/lib/dracut/dracut.conf.d/99-chauvenity-keymap.conf`
   (`install_items+=`).
2. Bake `rd.vconsole.keymap=fr` into the image kernel cmdline via a bootc
   kargs drop-in `/usr/lib/bootc/kargs.d/10-chauvenity-keymap.toml`, so the
   initramfs selects `fr` before the cryptsetup prompt on fresh installs and
   on every update.

The real-root / desktop session keymap is unaffected — it is driven by
`/etc/vconsole.conf` (host state, currently `fr-afnor`) and the X11/Wayland
input source, which load long after the initramfs and have nothing to do
with the LUKS prompt.

## Per-host cleanup (this machine)

The interactive `rpm-ostree kargs --replace=...` used during diagnosis left a
malformed karg:

    vconsole.keymap=vconsole.keymap=fr

Remove it once on this host:

    sudo rpm-ostree kargs --delete='vconsole.keymap=vconsole.keymap=fr'

The manually added `rd.vconsole.keymap=fr` may stay until the machine is
rebased onto an image carrying the kargs.d drop-in (a duplicate, identical
karg is harmless); delete it later with `--delete` if desired.

## Alternatives rejected

- **Keep `fr-afnor` and only add the `rd.` prefix.** Untested; `fr` works.
  No reason to chase the afnor variant for a single-user image.
- **`localectl set-keymap fr` on the host.** Also changes the session/TTY
  keymap, altering the AZERTY-afnor desktop layout the user wants. Out of
  scope.

## Removal criteria

Same upstream trigger as ADR 0001: when bluefin-dx ships keymaps in its
pre-baked initramfs again, revisit whether the dracut drop-in is still
needed (CI `upstream-initramfs-check.yml › Job A`). The kargs.d drop-in is
independent and low-cost; keep it unless it conflicts.

## Removal record (2026-06-15)

Job A fired RED: upstream `bluefin-dx` pre-baked initramfs again ships a real
`usr/lib/kbd/keymaps/xkb/fr.map.gz` (4077 bytes, valid keymap data; verified
by unpacking the zstd cpio of the pinned base digest `a81bde00`). A bare
`lsinitrd -f` reports the file as 0 bytes — a cpio hardlink artifact, not
emptiness.

The dracut drop-in
`/usr/lib/dracut/dracut.conf.d/99-chauvenity-keymap.conf` was therefore
removed. The kargs.d drop-in `rd.vconsole.keymap=fr` is retained: it selects
the keymap and is independent of who supplies `fr.map.gz`. Job B still
guards that our published image's initramfs contains the keymap (now via
upstream).
