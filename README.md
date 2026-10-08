# chauvenity-os

[![bluebuild build badge](https://github.com/ekans/chauvenity-os/actions/workflows/build.yml/badge.svg)](https://github.com/ekans/chauvenity-os/actions/workflows/build.yml)

Personal Fedora Atomic development workstation for Elixir/Erlang work at Airnity, built with [BlueBuild](https://blue-build.org/).

**Why "chauvenity"?** A French wordplay on my company name: Airnity → air ≈ hair → *chauve* (French for bald) + nity = chauvenity.

## Base Image

Built on [bluefin-dx](https://github.com/ublue-os/bluefin) (stable), the developer experience variant of Universal Blue's Fedora Atomic image.

## What's Included

### Development Tools
- **mise** (COPR `jdxcode/mise`) — polyglot dev tool version manager
- **ghostty** (COPR `scottames/ghostty`) — GPU-accelerated terminal
- **1password** (via `bling` module)
- **waydroid** (COPR `aleasto/waydroid`) — Android container runtime

### Browser
- **Brave** — privacy-focused browser

### Erlang/OTP Build Dependencies
- autoconf, automake
- ncurses-devel, wxBase, wxGTK-devel
- erlang-odbc, unixODBC-devel, libiodbc
- java-25-openjdk-devel
- fop

### Phoenix / Brod Dependencies
- inotify-tools (Phoenix live reload)
- cmake (Brod / Kafka build)

### Desktop Sessions

GDM offers two sessions. **GNOME** (from bluefin-dx) is unchanged and remains
the default — GDM remembers the last session per user in AccountsService, and
nothing here touches a GNOME package, a GNOME default or a GDM setting.

**Niri** is a second session: the [niri](https://github.com/YaLTeR/niri)
scrolling-tiling Wayland compositor with a
[Quickshell](https://quickshell.org/) bar. Its point is live editing — niri
re-reads its config and Quickshell reloads its QML the moment either file is
saved, so the desktop changes without logging out. Everything it needs comes
from the Fedora repositories — `niri`, `xwayland-satellite`, plus `fuzzel`
(launcher), `swayidle`, `swaylock`, `mate-polkit`,
`wireplumber` and `brightnessctl` — except `quickshell`, which comes from the
[`errornointernet/quickshell`](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/)
COPR so the image ships the latest upstream release (Fedora's package is a
0.2.1 snapshot). Screenshare
goes through `xdg-desktop-portal-gnome`, the same portal GNOME uses, because
niri implements the `org.gnome.Mutter.ScreenCast` interface. `Mod+Shift+/`
lists the main keybinds.

The bar shows this output's workspaces, the focused window's title, volume,
battery and the clock.

No notification daemon is installed: notifications are left to your own copy
of the bar (see below), which serves `org.freedesktop.Notifications` with
Quickshell's notification service, so you can change them without building an
image. Until you take the bar over, the niri session shows no notifications.

#### Taking it over

System defaults ship read-only in `/etc`. Override niri's per-user by including
it from your own config, then edit live; later settings win, and you keep
getting changes made to `/etc/niri/config.kdl`:

```kdl
// ~/.config/niri/config.kdl
include "/etc/niri/config.kdl"

// your overrides below, e.g.
layout { gaps 4; }
```

The bar is taken over by copying its directory:

```bash
mkdir -p ~/.config/quickshell
cp -r /etc/xdg/quickshell/chauvenity ~/.config/quickshell/
systemctl --user restart chauvenity-quickshell
```

Each line matters. Without the `mkdir`, `cp -r` creates
`~/.config/quickshell` *as* the copy, so the files land one directory too high
and are silently ignored. And copy the **directory**, not just `shell.qml`:
Quickshell resolves `-c chauvenity` to the first `chauvenity/` it finds across
the XDG config dirs, so a lone `shell.qml` in `~/.config` shadows the shipped
directory, and any other file the bar loads from it is no longer found.

The one-time `restart` is because the running bar is still watching
`/etc/xdg/quickshell/chauvenity`; it picks up the new location on restart and
watches your copy live from then on. niri needs no equivalent — it switches to
`~/.config/niri/config.kdl` on the next save. Unlike the niri include, a copied
bar no longer receives changes made to the image's copy.

> [!WARNING]
> Run `niri validate` before logging out after editing `~/.config/niri/config.kdl`.
> If that file exists but fails to parse, niri does **not** fall back to
> `/etc/niri/config.kdl` — it starts on upstream's default config instead: your
> own binds are gone, and its terminal bind (`Mod+T`, alacritty) does nothing on
> this image. The lock screen and other session services keep running.

#### How the session starts

The compositor comes from the `niri` RPM's own
`/usr/share/wayland-sessions/niri.desktop`. Everything else — the bar, idle
and lock handling, the polkit agent, the keyring components and the SSH agent
(`gcr-ssh-agent`) — runs as systemd user units pulled in by a drop-in on `niri.service`, so they are niri-only and
survive a broken `config.kdl`. The reasoning is in
[`niri.service.d/10-chauvenity-session.conf`](./files/system/usr/lib/systemd/user/niri.service.d/10-chauvenity-session.conf).
To drop one:

```bash
systemctl --user mask chauvenity-polkit-agent.service
```

The
[`niri-session-config-check`](./.github/workflows/niri-session-config-check.yml)
workflow runs `niri validate` and `qmllint` on every PR that touches the
session.

### Dotfiles
Managed via [chezmoi](https://www.chezmoi.io/) from [ekans/dotfiles](https://github.com/ekans/dotfiles).

## Installation

> [!WARNING]
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing Fedora Atomic installation:

1. Rebase to the unsigned image (to get signing keys installed):
   ```
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/ekans/chauvenity-os:latest
   ```

2. Reboot:
   ```
   systemctl reboot
   ```

3. Rebase to the signed image:
   ```
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ekans/chauvenity-os:latest
   ```

4. Reboot again:
   ```
   systemctl reboot
   ```

The `latest` tag always points to the most recent build using the Fedora version specified in `recipes/recipe.yml`.

## Local Development

Tasks are exposed through [mise-en-place](https://mise.jdx.dev/) in [`mise.toml`](./mise.toml). The host needs the [BlueBuild CLI](https://blue-build.org/learn/getting-started/#installing-the-bluebuild-cli), podman, qemu, libvirt, `yq` and `shellcheck`; mise installs the pinned [bcvk](https://github.com/bootc-dev/bcvk). All tasks run without root except `rebase` and `generate-iso`.

```bash
mise tasks               # list available tasks
mise run verify          # check, build, test:contract, test:boot: run this after a change
mise run check           # seconds, no build: recipe schema, shellcheck, initramfs still last
mise run build           # ~3 min, seconds when cached: image in podman as localhost/chauvenity-os:local
mise run test:contract   # seconds: the image has what the recipes promise, without booting it
mise run test:boot       # ~1 min: boot it in a throwaway VM, check units, desktop, groups
mise run vm              # ~15 min: real install to a libvirt VM, the boot checks plus karg and SELinux
mise run vm:view         # open the VM's desktop (vm:ssh for a shell, vm:rm to delete it)
mise run clean           # remove the VM and the local image
mise run rebase          # build and rebase the running system onto it
mise run generate-iso    # generate a bootable ISO from the published image
```

### Verifying a change

Run `mise run verify`; it stops at the first failing step and exits non-zero. Every check prints one line, `ok   <name>` or `FAIL <name>` followed by the evidence (the command's output, or `systemctl status` of a failed unit), so a person or an agent can tell what broke without re-running anything.

- `test:contract` runs [`test/image-contract.sh`](./test/image-contract.sh), the same script the weekly [`image-contract`](./.github/workflows/image-contract.yml) workflow runs on the published image. Packages added to a recipe's `dnf` module are checked automatically; anything else a change promises needs a `check` line there.
- `test:boot` ([`test/boot.sh`](./test/boot.sh)) boots the container directly, which is fast but not a real install: SELinux is off and `kargs.d` is not applied. Use `mise run vm` ([`scripts/vm.sh`](./scripts/vm.sh)) for changes to boot, kargs or SELinux, and to look at the desktop.

The local build differs from CI: it is not rechunked or signed, and its signature policy trusts `cosign.pub` for `localhost/chauvenity-os` rather than `ghcr.io/ekans/chauvenity-os`.

## Verification

Images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). Verify with:

```bash
cosign verify --key cosign.pub ghcr.io/ekans/chauvenity-os
```

## Known issues / workarounds

- **LUKS keymap forced for boot prompt (F44+).** F44 dracut 108 silently
  drops keymaps from the upstream bluefin-dx pre-baked initramfs, which
  broke AZERTY LUKS unlock. chauvenity-os selects the `fr` keymap for the
  boot prompt with the karg `rd.vconsole.keymap=fr` (bootc `kargs.d`
  drop-in). `fr.map.gz` itself is supplied by upstream bluefin-dx's
  pre-baked initramfs again, so the local dracut drop-in was removed. The
  desktop session / TTY keymap is unaffected (still driven by
  `/etc/vconsole.conf`, e.g. `fr-afnor`).
  Tracked by [`docs/adr/0002-fr-keymap-rd-vconsole-karg.md`](./docs/adr/0002-fr-keymap-rd-vconsole-karg.md)
  (supersedes 0001)
  and the keymap checks in [`test/image-contract.sh`](./test/image-contract.sh),
  run weekly on the published image by the
  [`image-contract`](./.github/workflows/image-contract.yml) workflow (red
  means the initramfs lost the keymap or the karg is gone).

## Dependency updates

Managed by [Renovate](https://docs.renovatebot.com/) (config: `.github/renovate.json5`, extends [`config:best-practices`](https://docs.renovatebot.com/upgrade-best-practices/)).

Coverage:
- GitHub Actions in `.github/workflows/` (built-in `github-actions` manager).
- Tools pinned under `[tools]` in `mise.toml`, i.e. bcvk (built-in `mise` manager).
- Upstream RPMs installed by URL in `recipes/*.yml` (none at the moment), via inline `# renovate: datasource=... depName=...` annotations on the line above the version.
- Base image digest in `recipes/recipe.yml` (`image-version: stable@sha256:...`), bumped by Renovate when upstream changes; each bump rebuilds the image. The [`bluebuild`](./.github/workflows/build.yml) workflow also rebuilds daily at 06:00 UTC, as in the [BlueBuild template](https://github.com/blue-build/template), to pick up updated layered packages. See [`docs/adr/0003-pin-base-digest-renovate.md`](./docs/adr/0003-pin-base-digest-renovate.md).

Requires the [Mend Renovate GitHub App](https://github.com/apps/renovate) to be installed on the repository for PRs to be opened.
