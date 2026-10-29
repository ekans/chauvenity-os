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

The [greetd](https://sr.ht/~kennylevinsen/greetd/) login screen offers **niri**
and the unchanged **GNOME** session from bluefin-dx. Niri is a scrolling-tiling
Wayland compositor with a [Quickshell](https://quickshell.org/) bar. Its config
and the bar reload when saved, so you can customize the desktop without logging
out. `Mod+Shift+/` lists the main keybinds.

To customize niri, include the system config in your own config; your settings
below the include override its defaults:

```kdl
// ~/.config/niri/config.kdl
include "/etc/niri/config.kdl"
```

To customize the bar, copy its config and restart it once:

```bash
mkdir -p ~/.config/quickshell
cp -r /etc/xdg/quickshell/chauvenity ~/.config/quickshell/
systemctl --user restart chauvenity-quickshell
```

Copy the whole directory, not just `shell.qml`, so the bar can find its other
files. The `mkdir` ensures the files land in the right location.

Validate niri config before logging out with `niri validate`.

For testing desktop changes without opening a window in your live session, use
`niri-sandbox`:

```bash
niri-sandbox up -c ~/.config/niri/config.kdl
niri-sandbox spawn qs -c chauvenity
niri-sandbox shot /tmp/bar.png
niri-sandbox down
```

For implementation details, see the session and greeter configuration under
[`files/system`](./files/system) and [`recipes/greetd.yml`](./recipes/greetd.yml).

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

Tasks are exposed through [mise](https://mise.jdx.dev/) in [`mise.toml`](./mise.toml).
Install the [BlueBuild CLI](https://blue-build.org/learn/getting-started/#installing-the-bluebuild-cli),
podman, qemu, libvirt, `yq` and `shellcheck` first.

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

Run `mise run verify` after changes. Use `mise run vm` for changes to boot,
SELinux, greetd or PAM.

## Verification

Images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). Verify with:

```bash
cosign verify --key cosign.pub ghcr.io/ekans/chauvenity-os
```

## Known issues / workarounds

- **LUKS keyboard layout on F44+.** The boot prompt uses the French keymap to
  support AZERTY. See the [keymap decision](./docs/adr/0002-fr-keymap-rd-vconsole-karg.md).
- **First-boot app links.** Brave and 1Password links under `/opt` are created
  at boot by
  [`00-chauvenity-var-opt.conf`](./files/system/usr/lib/tmpfiles.d/00-chauvenity-var-opt.conf).

## Dependency updates

Managed by [Renovate](https://docs.renovatebot.com/).

- Base image digest in `recipes/recipe.yml` (`image-version: stable@sha256:...`), bumped by Renovate when upstream changes; each bump rebuilds the image. The [`bluebuild`](./.github/workflows/build.yml) workflow also rebuilds daily at 06:00 UTC, as in the [BlueBuild template](https://github.com/blue-build/template), to pick up updated layered packages. See [`docs/adr/0003-pin-base-digest-renovate.md`](./docs/adr/0003-pin-base-digest-renovate.md).

Requires the [Mend Renovate GitHub App](https://github.com/apps/renovate) to be installed on the repository for PRs to be opened.
