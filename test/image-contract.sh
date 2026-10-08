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
check 'sysusers recreates the 1Password groups' 'grep -qx "g onepassword 1500" /usr/lib/sysusers.d/onepassword.conf && grep -qx "g onepassword-cli 1600" /usr/lib/sysusers.d/onepassword-cli.conf'
check 'no rpm-ostree 1Password group entries'   '! test -e /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword.conf && ! test -e /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword-cli.conf'
check 'no 1Password repo left behind'           '! test -e /etc/yum.repos.d/1password.repo'

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

exit $fail
