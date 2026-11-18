#!/usr/bin/env bash
# Copy the login greeter's QML from the dotfiles repo into the image's tree.
#   scripts/sync-greeter.sh DOTFILES_CHECKOUT
# The greeter is written and tested in ekans/dotfiles (quickshell/), where
# its tests and proof.sh live. greetd's greeter user has no home to apply
# chezmoi to, so the image carries a copy of the chauvenity-greeter and
# chauvenity-lock folders. QML imports a folder, not a file (the greeter's
# `import "lock"` makes every .qml beside LockFace.qml a type), so both are
# copied whole, minus the paths in skip below. Re-run after the greeter changes
# and commit the result.
# SYNC_GREETER_DST overrides where the folders go.
set -euo pipefail
cd "$(dirname "$0")/.."
src=${1:?usage: sync-greeter.sh DOTFILES_CHECKOUT}/quickshell
dst=${SYNC_GREETER_DST:-files/system/etc/xdg/quickshell}

skip=(
  'chauvenity-greeter/tests/*'
  'chauvenity-lock/tests/*'
  chauvenity-lock/shell.qml       # the lock's own entry point, which would make `qs -c chauvenity-lock` an image config
  chauvenity-lock/lock.sh
  chauvenity-lock/art/sprites.sh
)

[[ $(readlink "$src/chauvenity-greeter/lock") == ../chauvenity-lock ]] || { echo "sync-greeter: lock is not ../chauvenity-lock in $src" >&2; exit 1; }
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
(cd "$src" && find chauvenity-greeter chauvenity-lock -type f) | while read -r f; do
  # shellcheck disable=SC2053  # $s is a glob
  for s in "${skip[@]}"; do [[ $f == $s ]] && continue 2; done
  install -D -m 644 "$src/$f" "$stage/$f"
done
ln -s ../chauvenity-lock "$stage/chauvenity-greeter/lock"

command -v qs >/dev/null || { echo "sync-greeter: no qs to load the copy with; install quickshell" >&2; exit 1; }
# Offscreen Qt has no layer-shell, so a copy that loads stops at the greeter's
# PanelWindow, and exits 255 just like one that does not. Read the log.
# It never draws either, so a missing image such as art/glow.png still loads.
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
