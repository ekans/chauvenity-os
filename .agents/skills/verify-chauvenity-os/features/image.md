# Image build and boot

What the user installs: the bootc image built from `recipes/` and `files/`. A
change to a recipe, a package, a systemd unit, a tmpfiles or preset drop-in, a
karg, PAM or greetd has to survive a build and a boot, and the image has to
keep every promise the recipes make.

## Sub-features

- `img-check` the recipe validates, the shell scripts pass shellcheck, and `initramfs` stays the last module.
- `img-build` the image builds into podman as `localhost/chauvenity-os:local`.
- `img-contract` the built image has what the recipes promise, without booting it.
- `img-boot` the image boots in a throwaway VM with the expected units, the desktop, groups and greetd as the display manager.
- `img-install` a real install to a libvirt VM, with kargs and SELinux enforcing.

## How to get to it (user POV)

- `rpm-ostree rebase` onto the published image and reboot (the README's Installation).
- Locally, `mise run rebase` onto a local build.

## Driving it with desk

`desk` is not used here: the image has its own harness, `mise` tasks that print
`ok   <name>` or `FAIL <name>` plus evidence, one line per check.

Preconditions:

- `bluebuild`, `podman`, `shellcheck`, `yq` and `bcvk` (pinned by `mise.toml`) are on PATH.
- The checkout's `mise.toml` is trusted (`mise trust`), or `mise run` refuses to run.

- **Static checks.** Run `mise run check 2>&1 | tee "$OUT/image/check.txt"`. `Recipe recipes/recipe.yml is valid`, no shellcheck output, exit 0. Seconds.
- **Build.** Run `mise run build 2>&1 | tee "$OUT/image/build.txt"`. Exit 0, and `podman images localhost/chauvenity-os:local` shows a fresh `Created`. About 3 min, seconds when cached.
- **Contract.** Run `mise run test:contract 2>&1 | tee "$OUT/image/contract.txt"`. Only `ok` lines; a package added to a recipe's `dnf` module is checked automatically, anything else needs a `check` line in `test/image-contract.sh`.
- **Boot.** Run `mise run test:boot 2>&1 | tee "$OUT/image/boot.txt"`. Only `ok` lines, including that greetd, not GDM, runs. About 1 min.
- **All four.** `mise run verify` runs check, build, contract and boot, stopping at the first failure.
- **Real install.** For boot, kargs, SELinux, greetd or PAM changes, run `mise run vm` (about 15 min), then `mise run vm:ssh` to inspect, `mise run vm:view` to look at the desktop.

## Gotchas

- `test:boot` boots the container directly: SELinux is off and `kargs.d` is not applied. A green `test:boot` does not prove a karg, an SELinux label or the real greetd login; that needs `mise run vm`.
- The local build is not rechunked or signed, and trusts `cosign.pub` for `localhost/chauvenity-os` only. Signing is CI's business.
- `mise run vm:view` opens a window on the user's live session. Ask before running it, or use `mise run vm:ssh` and screenshots taken inside the VM.
- Never run `mise run rebase` or `generate-iso` to verify: they use `sudo`, and rebase changes the machine the user is working on.
- Cleanup is `mise run vm:rm` for the VM, `mise run clean` for the VM and the local image. Neither touches `$OUT`.
