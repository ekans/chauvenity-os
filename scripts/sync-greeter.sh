#!/usr/bin/env bash
# Copy the login greeter's QML from the dotfiles repo into the image's tree.
#   scripts/sync-greeter.sh DOTFILES_CHECKOUT
# The greeter is written and tested in ekans/dotfiles (quickshell/), where
# its tests and proof.sh live. greetd's greeter user has no home to apply
# chezmoi to, so the image carries a copy of the chauvenity-greeter and
# chauvenity-lock folders. QML imports a folder, not a file (the greeter's
# `import "lock"` makes every .qml beside LockFace.qml a type), so both are
# copied whole, minus the paths in skip below. chauvenity-greeter/lock is a
# symlink to ../chauvenity-lock, which is how the greeter imports LockFace.qml;
# both folders must stay side by side. Re-run after the greeter changes and
# commit the result.
# The copy is built in a temporary folder and loaded with Quickshell's
# offscreen platform first, and only a copy that loads replaces the image's.
# That load resolves every QML type and script but never draws, so a missing
# image such as art/glow.png gets past it. Copying folders whole is what
# covers those.
# SYNC_GREETER_DST overrides where the folders go (an absolute path, for tests).
set -euo pipefail
cd "$(dirname "$0")/.."
src=${1:?usage: sync-greeter.sh DOTFILES_CHECKOUT}/quickshell
dst=${SYNC_GREETER_DST:-files/system/etc/xdg/quickshell}

skip=(
  'chauvenity-greeter/tests/*'    # run from the dotfiles checkout, never loaded
  'chauvenity-lock/tests/*'
  chauvenity-lock/shell.qml       # the lock's own entry point, which would make `qs -c chauvenity-lock` an image config
  chauvenity-lock/lock.sh         # starts the user's lock session, not the greeter
  chauvenity-lock/art/sprites.sh  # draws art/*.png, which ship already drawn
)

[[ $(readlink "$src/chauvenity-greeter/lock") == ../chauvenity-lock ]] || { echo "sync-greeter: lock is not ../chauvenity-lock in $src" >&2; exit 1; }
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
# find -type f skips the lock symlink, so chauvenity-lock is copied once, by its own path.
(cd "$src" && find chauvenity-greeter chauvenity-lock -type f) | while read -r f; do
  # shellcheck disable=SC2053  # $s is a glob
  for s in "${skip[@]}"; do [[ $f == $s ]] && continue 2; done
  install -D -m 644 "$src/$f" "$stage/$f"
done
ln -s ../chauvenity-lock "$stage/chauvenity-greeter/lock"

command -v qs >/dev/null || { echo "sync-greeter: no qs to load the copy with; install quickshell" >&2; exit 1; }
# Offscreen Qt has no layer-shell, so a copy that loads stops at the greeter's
# PanelWindow, and exits 255 just like one that does not. Read the log.
log=$(timeout 120 env -u WAYLAND_DISPLAY -u DISPLAY -u GREETD_SOCK \
  QT_QPA_PLATFORM=offscreen qs -p "$stage/chauvenity-greeter" --no-color 2>&1) || true
if ! grep -q '^ ERROR:   caused by @shell\.qml\[[0-9:]*\]: No PanelWindow backend loaded\.$' <<<"$log" ||
  grep '^ *ERROR:' <<<"$log" | grep -qv -e '^ ERROR: Failed to load configuration$' -e 'No PanelWindow backend loaded\.$'; then
  printf '%s\n' "$log" >&2
  echo "sync-greeter: the copy does not load, nothing was installed" >&2
  exit 1
fi

mkdir -p "$dst"
rm -rf "${dst:?}/chauvenity-greeter" "$dst/chauvenity-lock"
mv "$stage/chauvenity-greeter" "$stage/chauvenity-lock" "$dst/"
echo "synced the greeter from $(git -C "$src" rev-parse --short HEAD)"
