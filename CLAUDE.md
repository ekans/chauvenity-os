# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

chauvenity-os is a custom Fedora Atomic OS image built using [BlueBuild](https://blue-build.org/). It extends the `ghcr.io/ublue-os/bluefin-dx` base image with additional packages, flatpaks, and system configurations.

## Build Process

The image is built automatically via GitHub Actions. There is no local build command - all builds happen in CI.

- **Automatic builds**: Daily at 06:00 UTC and on every push (except markdown-only changes)
- **Manual builds**: Trigger via GitHub Actions workflow dispatch
- **CI workflow**: `.github/workflows/build.yml` uses `blue-build/github-action@v1.9`

## Project Structure

- `recipes/recipe.yml` - Main image recipe defining base image, modules, and packages
- `files/system/` - System files copied to `/` in the built image (etc, usr)
- `modules/` - Custom BlueBuild modules (currently empty)
- `cosign.pub` / `cosign.key` - Sigstore signing keys for image verification

## Recipe Configuration

The recipe (`recipes/recipe.yml`) uses BlueBuild module types:
- `files` - Copy system files
- `default-flatpaks` - Flatpak configuration
- `soar` - Package manager with auto-upgrade
- `chezmoi` - Dotfiles management (pulls from github.com/ekans/dotfiles)
- `dnf` - RPM packages and repos (mise, Brave, Erlang/Phoenix/Brod dependencies)
- `bling` - Additional tools (1password)
- `signing` - Image signing configuration

## Making Changes

1. Edit `recipes/recipe.yml` to add/remove packages or modules
2. Add system files to `files/system/etc/` or `files/system/usr/`
3. Add custom modules to `modules/`
4. Push to trigger a build

See [BlueBuild docs](https://blue-build.org/how-to/setup/) for module documentation.
