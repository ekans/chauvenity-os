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
- **Docker Sandboxes (sbx)** — installed from upstream GitHub release
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
scrolling-tiling Wayland compositor. Its point is live editing — niri re-reads
its config the moment the file is saved, so the desktop changes without logging
out. Everything it needs comes from the Fedora repositories (no COPR): `niri`,
`xwayland-satellite`, plus `fuzzel` (launcher), `swayidle`, `swaylock`, `mako`
(notifications), `mate-polkit`, `wireplumber`, `brightnessctl` and `kanshi`
(display profiles). Screenshare
goes through `xdg-desktop-portal-gnome`, the same portal GNOME uses, because
niri implements the `org.gnome.Mutter.ScreenCast` interface. There is no panel
yet; `Mod+Shift+/` lists the main keybinds.

#### Taking it over

The system default ships read-only in `/etc`. Override it per-user by including
it from your own config, then edit live; later settings win, and you keep
getting changes made to `/etc/niri/config.kdl`:

```kdl
// ~/.config/niri/config.kdl
include "/etc/niri/config.kdl"

// your overrides below, e.g.
layout { gaps 4; }
```

> [!WARNING]
> Run `niri validate` before logging out after editing `~/.config/niri/config.kdl`.
> If that file exists but fails to parse, niri does **not** fall back to
> `/etc/niri/config.kdl` — it starts on upstream's default config instead: your
> own binds are gone, and its terminal bind (`Mod+T`, alacritty) does nothing on
> this image. The lock screen and other session services keep running.

#### How the session starts

The compositor comes from the `niri` RPM's own
`/usr/share/wayland-sessions/niri.desktop`. Everything else — idle and lock
handling, the polkit agent, notifications (expiring after 10 s), display
profiles (`kanshi`), the keyring components and the SSH agent (`gcr-ssh-agent`)
— runs as systemd user units
pulled in by a drop-in on `niri.service`, so they are niri-only and survive a
broken `config.kdl`. The reasoning is in
[`niri.service.d/10-chauvenity-session.conf`](./files/system/usr/lib/systemd/user/niri.service.d/10-chauvenity-session.conf).
To drop one:

```bash
systemctl --user mask chauvenity-polkit-agent.service
```

#### External monitors

While any external monitor is connected, the laptop panel (`eDP-1`) is off;
unplugging the last one turns it back on. kanshi does this from the shipped
[`/etc/kanshi/config`](./files/system/etc/kanshi/config). Writing
`~/.config/kanshi/config` replaces that file entirely; start it with
`include /etc/kanshi/config` to keep the shipped profiles, then
`systemctl --user restart kanshi`.

Editing an `output` block in your niri config makes niri re-apply its own
output settings, which turns the panel back on. kanshi does not notice, because
the same monitors are still connected; `kanshictl reload` switches the panel off
again.

The
[`niri-session-config-check`](./.github/workflows/niri-session-config-check.yml)
workflow runs `niri validate` on every PR that touches the session.

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

Local build and rebase tasks are exposed through [mise-en-place](https://mise.jdx.dev/) in [`mise.toml`](./mise.toml). The [BlueBuild CLI](https://blue-build.org/learn/getting-started/#installing-the-bluebuild-cli) must be installed on the host.

```bash
mise tasks               # list available tasks
mise run build           # build the image locally
mise run rebase          # build and rebase the running system onto it
mise run generate-iso    # generate a bootable ISO from the published image
```

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
  and the [`initramfs-keymap-check`](./.github/workflows/initramfs-keymap-check.yml)
  workflow (positive check: red means our image's initramfs lost the
  keymap).

## Dependency updates

Managed by [Renovate](https://docs.renovatebot.com/) (config: `.github/renovate.json5`, extends [`config:best-practices`](https://docs.renovatebot.com/upgrade-best-practices/)).

Coverage:
- GitHub Actions in `.github/workflows/` (built-in `github-actions` manager).
- Pinned upstream RPMs in `recipes/*.yml` via inline `# renovate: datasource=... depName=...` annotations on the line above the version.
- Base image digest in `recipes/recipe.yml` (`image-version: stable@sha256:...`), bumped by Renovate to drive rebuilds only when upstream changes. See [`docs/adr/0003-pin-base-digest-renovate.md`](./docs/adr/0003-pin-base-digest-renovate.md).

Requires the [Mend Renovate GitHub App](https://github.com/apps/renovate) to be installed on the repository for PRs to be opened.
