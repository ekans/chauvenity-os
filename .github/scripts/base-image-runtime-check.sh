#!/usr/bin/env bash
# Does the session actually RUN on the base image we pin?
#
# The config check next door installs the session's packages into a fresh
# Fedora 44 container, where every library is at the newest release. The image
# is not that: it is whatever bluefin-dx digest `recipes/recipe.yml` pins, and
# the base can lag Fedora by a patch release. That gap is invisible to a fresh
# container, and it once let this bar ship unable to start at all —
# quickshell was built against Qt 6.11.2 but only requires
# `libQt6Core.so.6(Qt_6.11)`, so dnf was happy to leave the base's 6.11.1 in
# place and `qs` died at load time on an undefined symbol.
#
# So: install into the pinned base, exactly as the dnf module does, then run
# the binaries. Usage:
#
#   .github/scripts/base-image-runtime-check.sh [--no-qt-fix]
#
# --no-qt-fix skips the recipe's Qt upgrade script, which is how you make this
# go red on the bug it exists for.

set -euo pipefail

cd "$(dirname "$0")/../.."

recipe=recipes/recipe.yml
base=$(grep -oP '^base-image:\s*\K\S+' "$recipe")
digest=$(grep -oP '^image-version:.*@\Ksha256:[a-f0-9]+' "$recipe")
[ -n "$base" ] && [ -n "$digest" ] || { echo "could not read base image or digest from $recipe"; exit 1; }

# The package list is read out of the recipe, so it cannot drift from what the
# build installs. Plain awk rather than a YAML parser so this needs nothing
# installed: take the list items under `packages:` and stop at the first line
# that dedents out of the block.
mapfile -t packages < <(awk '
  /^[[:space:]]*packages:[[:space:]]*$/ { ind = match($0, /[^ ]/); inblk = 1; next }
  inblk {
    if ($0 ~ /^[[:space:]]*(#.*)?$/) next
    if (match($0, /[^ ]/) <= ind) { inblk = 0; next }
    if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      print line
    }
  }
' recipes/niri-session.yml)
[ "${#packages[@]}" -gt 0 ] || { echo "no packages parsed from recipes/niri-session.yml"; exit 1; }

qt_fix=files/scripts/upgrade-qt-for-quickshell.sh
if [ "${1:-}" = "--no-qt-fix" ]; then
  qt_fix=""
  echo ":: skipping the Qt upgrade script, to show this check can see the bug"
fi

echo ":: base   $base@$digest"
echo ":: packages (${#packages[@]}): ${packages[*]}"

cid=$(podman create "$base@$digest" sleep infinity)
trap 'podman rm -f "$cid" >/dev/null 2>&1 || true' EXIT
podman start "$cid" >/dev/null

podman exec "$cid" dnf install -y --setopt=install_weak_deps=False "${packages[@]}" >/tmp/base-install.log 2>&1 ||
  { echo "::error::dnf install failed on the pinned base"; tail -30 /tmp/base-install.log; exit 1; }

# The recipe's own script module, run exactly as the build runs it.
if [ -n "$qt_fix" ]; then
  podman cp "$qt_fix" "$cid":/tmp/qt-fix.sh
  podman exec "$cid" bash /tmp/qt-fix.sh >/tmp/qt-fix.log 2>&1 ||
    { echo "::error::$qt_fix failed on the pinned base"; tail -20 /tmp/qt-fix.log; exit 1; }
  grep -E '^(Qt before|Qt after|  qt6-qtbase )' /tmp/qt-fix.log || true
fi

status=0

echo ":: qs --version"
if podman exec "$cid" qs --version; then
  echo "ok  quickshell starts"
else
  echo "::error::quickshell cannot start on the pinned base image"
  podman exec "$cid" sh -c 'qs --version 2>&1 | tail -3' || true
  status=1
fi

echo ":: niri --version"
podman exec "$cid" niri --version || { echo "::error::niri cannot start on the pinned base image"; status=1; }

echo ":: QML smoke load of the shipped config"
podman cp files/system/etc/xdg/quickshell "$cid":/etc/xdg/quickshell
podman cp files/system/etc/niri "$cid":/etc/niri
# No compositor here, so the bar cannot be drawn. Loading it far enough to
# resolve every import and type is still what catches a missing Qt symbol or
# a component that does not exist.
smoke=$(podman exec "$cid" sh -c '
  QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp HOME=/root \
    timeout 60 qs -c chauvenity 2>&1 || true' | tail -20)
echo "$smoke"
if grep -q 'No PanelWindow backend loaded' <<<"$smoke"; then
  # Reached object creation: every import, type and symbol resolved, and the
  # only thing missing is the compositor this container does not have.
  echo "ok  QML resolved; stopped only for want of a compositor"
elif grep -qE 'undefined symbol|symbol lookup error' <<<"$smoke"; then
  echo "::error::the shipped QML hit a dynamic linker error on the pinned base"
  status=1
else
  echo "::error::the shipped QML did not load on the pinned base"
  status=1
fi

podman exec "$cid" sh -c 'niri validate -c /etc/niri/config.kdl' >/dev/null 2>&1 ||
  { echo "::error::niri rejected the shipped config on the pinned base"; status=1; }

[ $status -eq 0 ] && echo ":: PASS" || echo ":: FAIL"
exit $status
