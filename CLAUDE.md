# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

chauvenity-os is a custom Fedora Atomic OS image built using [BlueBuild](https://blue-build.org/). It extends the `ghcr.io/ublue-os/bluefin-dx` base image with additional packages and system configuration.

## Build Process

The image is built automatically via GitHub Actions. There is no local build command — all builds happen in CI.

- **Automatic builds**: daily at 06:00 UTC and on every push (except markdown-only changes)
- **Manual builds**: trigger via GitHub Actions workflow dispatch
- **CI workflow**: `.github/workflows/build.yml` uses `blue-build/github-action@v1.11`

## Project Structure

- `recipes/recipe.yml` — main image recipe (base image, top-level modules)
- `recipes/tools.yml` — user-facing tools (dnf repos+packages, bling)
- `recipes/erlang-deps.yml` — RPM build deps for compiling Erlang via mise
- `recipes/phoenix-deps.yml` — Phoenix / Brod build deps
- `cosign.pub` / `cosign.key` — Sigstore signing keys (private key is encrypted)

There are currently no `files/` or `modules/` directories; add them only when a
module needs them (e.g. `files/dnf/*.repo` for the dnf module, `modules/` for
custom local modules).

## Recipe Configuration

Top-level `recipes/recipe.yml` composes:
- `chezmoi` — dotfiles from `github.com/ekans/dotfiles`
- `from-file: tools.yml` — see below
- `from-file: erlang-deps.yml` — Erlang/OTP build deps
- `from-file: phoenix-deps.yml` — Phoenix / Brod build deps
- `signing` — cosign image signing

`tools.yml` uses:
- `dnf` — COPR repos (mise, ghostty, waydroid), `.repo` files (Brave, claude-desktop)
  and packages, including the sbx RPM installed directly from a GitHub release URL
- `bling` — 1password

## Making Changes

1. Edit `recipes/recipe.yml` or one of the `recipes/*.yml` includes to add/remove
   packages or modules
2. Add per-module assets under `files/<module>/` only if/when a module needs them
3. Add custom modules to `modules/` only if/when needed
4. Push to trigger a build

See [BlueBuild docs](https://blue-build.org/how-to/setup/) for module documentation.
