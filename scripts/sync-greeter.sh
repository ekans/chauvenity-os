#!/usr/bin/env bash
# Copy the login greeter's QML from the dotfiles repo into the image's tree.
#   scripts/sync-greeter.sh DOTFILES_CHECKOUT
# The greeter is written and tested in ekans/dotfiles (quickshell/), where
# its tests and proof.sh live. greetd's greeter user has no home to apply
# chezmoi to, so the image carries a copy of exactly what the greeter loads:
# not the lock screen's own shell.qml, lock.sh or any tests. chauvenity-greeter/lock
# is a symlink to ../chauvenity-lock, which is how the greeter imports
# LockFace.qml; both folders must stay side by side. Re-run after the greeter
# changes and commit the result.
set -euo pipefail
cd "$(dirname "$0")/.."
src=${1:?usage: sync-greeter.sh DOTFILES_CHECKOUT}/quickshell
dst=files/system/etc/xdg/quickshell

for f in chauvenity-greeter/shell.qml chauvenity-greeter/GreeterFace.qml chauvenity-greeter/greeter.mjs \
  chauvenity-lock/LockFace.qml chauvenity-lock/lock.mjs; do
  install -D -m 644 "$src/$f" "$dst/$f"
done
[[ $(readlink "$src/chauvenity-greeter/lock") == ../chauvenity-lock ]] || { echo "sync-greeter: lock is not ../chauvenity-lock in $src" >&2; exit 1; }
ln -sfn ../chauvenity-lock "$dst/chauvenity-greeter/lock"
echo "synced the greeter from $(git -C "$src" rev-parse --short HEAD)"
