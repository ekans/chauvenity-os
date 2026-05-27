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
- **claude-desktop** — Anthropic Claude desktop client
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

- **LUKS keymap baked into initramfs (F44+).** F44 dracut 108 silently
  drops keymaps from the upstream bluefin-dx pre-baked initramfs, which
  breaks AZERTY LUKS unlock. chauvenity-os force-includes `fr-afnor` via
  a dracut drop-in and regenerates the initramfs at image build time.
  Tracked by [`docs/adr/0001-bake-luks-keymap-into-initramfs.md`](./docs/adr/0001-bake-luks-keymap-into-initramfs.md)
  and the [`upstream-initramfs-check`](./.github/workflows/upstream-initramfs-check.yml)
  workflow (inverted-semantics watcher: red means upstream fixed it and the
  workaround can be removed).

## Dependency updates

Managed by [Renovate](https://docs.renovatebot.com/) (config: `.github/renovate.json5`, extends [`config:best-practices`](https://docs.renovatebot.com/upgrade-best-practices/)).

Coverage:
- GitHub Actions in `.github/workflows/` (built-in `github-actions` manager).
- Pinned upstream RPMs in `recipes/*.yml` via inline `# renovate: datasource=... depName=...` annotations on the line above the version.

Requires the [Mend Renovate GitHub App](https://github.com/apps/renovate) to be installed on the repository for PRs to be opened.
