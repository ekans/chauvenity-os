#!/usr/bin/env bash
# shellcheck disable=SC2016  # $... in a check expands inside the image, not here
# Image contract: what the recipes promise, read from the image without booting it.
#   test/image-contract.sh IMAGE
# Runs on a local build (mise run test:contract) and weekly on the published
# image (.github/workflows/image-contract.yml), so both check the same things.
# Needs bash, podman and yq.
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${1:?usage: image-contract.sh IMAGE}
fail=0
ctr=$(podman run -d --rm "$IMAGE" sleep infinity)
# --rm races this removal; never let cleanup replace the exit status.
trap 'podman rm -f -t0 --ignore "$ctr" >/dev/null 2>&1 || true' EXIT
check() {
  local out
  if out=$(podman exec "$ctr" bash -c "$2" 2>&1); then
    echo "ok   $1"
  else
    echo "FAIL $1"
    [[ -z $out ]] || tail -20 <<<"$out" | sed 's/^/     /'
    fail=1
  fi
}

check 'bootc container lint' 'bootc container lint'

# Every package a dnf module installs by name, read from the recipes so a new
# one is covered without touching this file. What scripts install, and any URL
# install (it has no name to read), is listed below.
mapfile -t packages < <(yq --no-doc '.modules[] | select(.type == "dnf") | .install.packages[] | select(test("^https?://") | not)' recipes/*.yml)
for p in "${packages[@]}" 1password 1password-cli; do
  check "package $p" "rpm -q $p"
done
# /opt is /var/opt, empty until boot: tmpfiles then links each /opt/<app> to
# the copy the dnf module moved to /usr/lib/opt. So read /opt apps from there;
# test/boot.sh checks the links.
for c in 'mise --version' 'ghostty --version' '/usr/lib/opt/brave.com/brave/brave-browser --version' 'op --version' 'chezmoi --version'; do
  check "runs: $c" "$c"
done

# files/scripts/install-1password.sh
check '1Password chrome-sandbox is setuid'      'test -u /usr/lib/opt/1Password/chrome-sandbox'
check '1Password BrowserSupport setgid to 1500' 'test -g /usr/lib/opt/1Password/1Password-BrowserSupport && test "$(stat -c %g /usr/lib/opt/1Password/1Password-BrowserSupport)" = 1500'
check 'op setgid to 1600'                       'test -g /usr/bin/op && test "$(stat -c %g /usr/bin/op)" = 1600'
check '1password-mcp setgid to 1700'            'test -g /usr/lib/opt/1Password/1password-mcp && test "$(stat -c %g /usr/lib/opt/1Password/1password-mcp)" = 1700'
check 'sysusers recreates the 1Password groups' 'grep -qx "g onepassword 1500" /usr/lib/sysusers.d/onepassword.conf && grep -qx "g onepassword-cli 1600" /usr/lib/sysusers.d/onepassword-cli.conf && grep -qx "g onepassword-mcp 1700" /usr/lib/sysusers.d/onepassword-mcp.conf'
# The next two match any 1Password group, not just the three above, so a group
# a newer 1Password adds (as onepassword-mcp was) fails here until it is pinned.
check 'no rpm-ostree 1Password group entries'   'shopt -s nullglob; f=(/usr/lib/sysusers.d/30-rpmostree-pkg-*onepassword*); printf "%s\n" "${f[@]}"; test ${#f[@]} -eq 0'
# A fresh install keeps the image's /etc/group, and sysusers never renumbers a
# group that exists: any entry here leaves its pinned GID above nameless.
check 'image /etc/group has no 1Password groups' '! grep "^onepassword" /etc/group'
check 'no 1Password repo left behind'           '! test -e /etc/yum.repos.d/1password.repo'

# This container's /var is empty, like a fresh install's first boot: run the
# boot's tmpfiles lines for /opt and check every /opt app gets its link.
check 'first boot links the /opt apps' 'systemd-tmpfiles --create --boot --prefix=/opt --prefix=/var/opt && for d in /usr/lib/opt/*; do test -L "/var/opt/${d##*/}" || { echo "no /opt/${d##*/}"; exit 1; }; done'

# LUKS unlock at the boot prompt needs both: fr.map.gz in the initramfs, and the
# karg that selects it. With the file but no karg, every boot falls back to
# QWERTY and the AZERTY passphrase fails. fr.map.gz comes from upstream
# bluefin-dx's pre-baked initramfs, so these also go red if upstream drops it.
check 'exactly one initramfs'       'shopt -s nullglob; imgs=(/usr/lib/modules/*/initramfs.img); test ${#imgs[@]} -eq 1'
check 'initramfs has the fr keymap' 'lsinitrd /usr/lib/modules/*/initramfs.img | grep -q "/fr\.map\.gz"'
# Match the kargs line, not the file: its comments quote the karg too.
check 'karg rd.vconsole.keymap=fr'  'grep -Eq "^kargs = \[.*\"rd\.vconsole\.keymap=fr\"" /usr/lib/bootc/kargs.d/10-chauvenity-keymap.toml'

# signing module: without these, `bootc upgrade` to the signed image fails.
# The policy entry is keyed by the name the image was built under:
# ghcr.io/ekans/chauvenity-os in CI, localhost/chauvenity-os locally.
check 'policy trusts the cosign key' 'jq -e "[.transports.docker[][] | select(.type == \"sigstoreSigned\" and .keyPath == \"/etc/pki/containers/chauvenity-os.pub\")] | length == 1" /etc/containers/policy.json && test -s /etc/pki/containers/chauvenity-os.pub'

# chezmoi module: applies ekans/dotfiles at first login, then keeps it updated.
check 'chezmoi units enabled' 'systemctl --global is-enabled chezmoi-init.service chezmoi-update.timer'

# The user's own Quickshell bar serves org.freedesktop.Notifications; anything
# D-Bus-activatable would take the name whenever the bar is down.
check 'nothing D-Bus-activates a notification daemon' '! grep -lsx "Name=org.freedesktop.Notifications" /usr/share/dbus-1/services/*.service'

# /usr/bin/niri-sandbox runs niri inside `mutter --headless`. mutter comes from
# the bluefin base, so this goes red if upstream drops it.
check 'niri-sandbox dependencies exist' 'for c in mutter niri dbus-daemon systemd-run; do command -v $c >/dev/null || { echo "no $c"; exit 1; }; done'

# greetd is the display manager (recipes/greetd.yml); gdm stays installed so
# going back is `systemctl enable gdm`. display-manager.service is the alias
# whichever of the two is enabled owns.
check 'greetd is the display manager'   '[ "$(readlink -f /etc/systemd/system/display-manager.service)" = /usr/lib/systemd/system/greetd.service ]'
check 'gdm is installed, not enabled'   'rpm -q gdm && ! systemctl is-enabled gdm.service'
# A fresh install applies every preset at its first boot, and
# 85-display-manager.preset enables gdm there. Without ours, which sorts first,
# this ends on gdm.service. A copy of the units stands in for the new root.
check 'a fresh install keeps greetd'    'r=$(mktemp -d); mkdir -p $r/usr/lib; cp -a /usr/lib/systemd $r/usr/lib/; systemctl --root=$r preset-all --preset-mode=full >/dev/null 2>&1; l=$(readlink $r/etc/systemd/system/display-manager.service); [ "$l" = /usr/lib/systemd/system/greetd.service ] || { echo "display-manager.service -> ${l:-nothing}"; exit 1; }'
# greetd runs in GDM's SELinux domain: these are the labels greetd-selinux gives.
check 'greetd has its SELinux labels'   'matchpathcon /usr/bin/greetd | grep -q xdm_exec_t && matchpathcon /etc/greetd/config.toml | grep -q xdm_etc_t'

# The greeter: Quickshell config chauvenity-greeter, which imports the lock
# screen's face through its lock -> ../chauvenity-lock symlink, so both folders
# have to survive the files module side by side. It is read by the greetd user.
check 'greetd starts the greeter in niri'   'grep -qx "command = \"niri -c /etc/greetd/niri.kdl\"" /etc/greetd/config.toml && grep -q "qs -c chauvenity-greeter" /etc/greetd/niri.kdl'
check 'greeter niri config is valid'        'niri validate -c /etc/greetd/niri.kdl'
check 'greeter keeps its lock symlink'      'd=/etc/xdg/quickshell/chauvenity-greeter; [ "$(readlink $d/lock)" = ../chauvenity-lock ] && test -f $d/lock/LockFace.qml'
check 'the greetd user can read the greeter' 'getent passwd greetd >/dev/null && runuser -u greetd -- sh -c "cat /etc/xdg/quickshell/chauvenity-greeter/shell.qml /etc/xdg/quickshell/chauvenity-greeter/lock/LockFace.qml /etc/xdg/quickshell/chauvenity-greeter/lock/lock.mjs /etc/greetd/niri.kdl >/dev/null"'
# tmpfiles creates the greeter user's home on a fresh install's empty /var, and
# masks the chezmoi unit the chezmoi module enables for every user.
check 'greeter home is created and chezmoi masked' 'r=$(mktemp -d); mkdir $r/etc; cp /etc/passwd /etc/group $r/etc/; systemd-tmpfiles --root=$r --create /usr/lib/tmpfiles.d/10-chauvenity-greetd.conf 2>&1; [ "$(readlink $r/var/lib/greetd/.config/systemd/user/chezmoi-init.service)" = /dev/null ] && [ "$(readlink $r/var/lib/greetd/.config/systemd/user/xdg-desktop-portal.service)" = /dev/null ]'
check 'the greeter lists both sessions'     'for s in gnome niri; do test -f /usr/share/wayland-sessions/$s.desktop || { echo "no $s.desktop"; exit 1; }; done'
check 'JetBrains Mono for the greeter clock' 'fc-list "JetBrains Mono" | grep -q .'

# /etc/pam.d/greetd: password-auth, not system-auth (this machine's has
# pam_fprintd first: the login would wait for a finger), and the keyring.
check 'greetd PAM uses password-auth'       'pam=$(grep -v "^#" /etc/pam.d/greetd); ! grep -q "system-auth\|fprintd" <<<"$pam" && grep -qE "^auth +substack +password-auth" <<<"$pam"'
check 'greetd PAM unlocks the keyring'      'grep -qE "^auth +optional +pam_gnome_keyring.so" /etc/pam.d/greetd && grep -qE "^session +optional +pam_gnome_keyring.so +auto_start" /etc/pam.d/greetd && test -e /usr/lib64/security/pam_gnome_keyring.so'

exit $fail
