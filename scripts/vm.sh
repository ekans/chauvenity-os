#!/usr/bin/env bash
# shellcheck disable=SC2016  # $... in a check expands inside the VM, not here
# Install the image to a disk and boot it as a libvirt VM, like a fresh laptop.
#   scripts/vm.sh IMAGE
# Run through `mise run vm`; `vm:view`, `vm:ssh` and `vm:rm` reach the same VM.
# Unlike test/boot.sh this is a real `bootc install`: SELinux enforcing, kargs.d
# applied, /etc and /var as a fresh install gets them. It takes minutes, and
# replaces the previous VM.
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${1:?usage: vm.sh IMAGE}
VM=${VM:-chauvenity-local}
# Session libvirt: no root, disks under ~/.local/share/libvirt.
CONNECT=${VM_CONNECT:-qemu:///session}
fail=0

# bcvk runs `bootc install` from a VM of the image itself, reached over SSH,
# and passes that VM no kargs; bluefin ships sshd disabled. So install the image
# plus sshd enabled, and nothing else. Removed once installed: as a child of
# $IMAGE it would stop the next build from deleting the build it replaces.
VM_IMAGE=$IMAGE-vm
trap 'podman rmi --ignore "$VM_IMAGE" >/dev/null 2>&1 || true' EXIT
printf 'FROM %s\nRUN systemctl enable sshd.service\n' "$IMAGE" | podman build -q -t "$VM_IMAGE" -f - . >/dev/null

# bluefin ships no bootc install config, so the filesystem has to be named;
# btrfs is what a bluefin install gets. Secure Boot off: the VM lacks the ublue
# key a real install enrols, so zfs and v4l2loopback would fail to load.
bcvk libvirt -c "$CONNECT" run --replace --name "$VM" --memory 8G --cpus 4 \
  --disk-size 60G --filesystem btrfs --firmware uefi-insecure \
  --graphical-console --ssh-wait "$VM_IMAGE"
# Each build gets its own base disk; drop the ones no VM uses any more.
bcvk libvirt -c "$CONNECT" base-disks prune >/dev/null

check() {
  local out
  # On a non-zero exit bcvk adds its own error to stderr; keep only the VM's.
  if out=$(timeout 180 bcvk libvirt -c "$CONNECT" ssh "$VM" -- "{ $2; } 2>&1" 2>/dev/null); then
    echo "ok   $1"
  else
    echo "FAIL $1"
    [[ -z $out ]] || printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
  fi
}

. test/runtime-checks.sh
# Only a real install has these; the ephemeral boot runs without them.
check 'karg on the command line' 'grep -qw rd.vconsole.keymap=fr /proc/cmdline || { cat /proc/cmdline; exit 1; }'
check 'SELinux enforcing'        'test "$(getenforce)" = Enforcing'

echo "desktop: mise run vm:view    shell: mise run vm:ssh    remove: mise run vm:rm"
exit $fail
