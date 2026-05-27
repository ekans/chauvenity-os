# ADR 0001 — Bake LUKS keymap into the image initramfs

Status: Accepted
Date: 2026-05-27

## Context

chauvenity-os image 44 (`ghcr.io/ekans/chauvenity-os:latest`, version
`44.20260519`) fails to unlock the LUKS root partition: the prompt accepts
input but loops back. Image 43 with the same password works.

Investigation:

- `/etc/vconsole.conf` correctly sets `KEYMAP=fr-afnor` on both images.
- Image 43 initramfs contains `/usr/lib/kbd/keymaps/xkb/fr-afnor.map.gz`
  (alongside 600+ other keymaps installed by `i18n_install_all="yes"` from
  `/usr/lib/dracut/dracut.conf.d/01-dist.conf`).
- Image 44 initramfs contains **zero** keymap files despite the same
  dracut config.
- Package diff: dracut `107-8.fc43` → `108-7.fc44`, kbd `2.8.0-3.fc43` →
  `2.9.0-3.fc44`. Regression in F44 dracut 108 silently drops keymaps from
  the bluefin-dx pre-baked initramfs.
- Effect: LUKS prompt falls back to US QWERTY, AZERTY passwords no longer
  unlock the disk.

No upstream issue or PR found in `ublue-os/bluefin`, `ublue-os/main`,
`dracut-ng`, or Fedora `kbd` tracking this specific regression at the
time of writing.

## Decision

Force-include the single keymap this image needs (`fr-afnor`) into the
initramfs at image build time, by shipping a dracut drop-in
(`/usr/lib/dracut/dracut.conf.d/99-chauvenity-keymap.conf`) and running the
BlueBuild `initramfs` module as the last recipe step.

The drop-in uses `install_items+=` (additive), so its load order against
the distro `01-dist.conf` does not matter. The `99-` prefix follows the
ecosystem "last wins" convention but is not required for correctness.

## Alternatives rejected

- **Per-host `rpm-ostree initramfs-etc --track=/etc/vconsole.conf`.**
  Recovers an already-installed machine but requires manual setup on every
  host and does nothing for fresh installs from the published image.
  Useful as a recovery hint, not as the fix.
- **Wait for upstream dracut/kbd fix.** Unknown timeline. The machine is
  unbootable today.
- **Switch base image away from bluefin-dx.** Disproportionate to a
  single-keymap regression.
- **Force-include every keymap (`install_items+=` glob).** YAGNI: this is
  a personal, single-user image. One keymap is enough.

## Removal criteria

Remove the drop-in, the `initramfs` module entry, and this ADR when CI
job `upstream-initramfs-check.yml › Job A` starts failing — that signals
upstream bluefin-dx now ships the keymap inside its pre-baked initramfs
and the workaround is redundant.
