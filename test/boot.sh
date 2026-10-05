#!/usr/bin/env bash
# Boot test: boot the image in a throwaway VM and run test/runtime-checks.sh.
#   test/boot.sh IMAGE
# Run through `mise run test:boot`, which puts the pinned bcvk on PATH.
# bcvk boots the container image directly, root over virtiofs: no disk image,
# no sudo. It is not a faithful install: SELinux is off and kargs.d is not
# applied, so the keymap karg is checked by image-contract.sh and scripts/vm.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${1:?usage: boot.sh IMAGE}
TIMEOUT=${TIMEOUT:-300}
VM=chauvenity-boot-$$
fail=0

# bluefin ships sshd disabled, and bcvk reaches the VM over SSH. --console
# puts the boot log in `podman logs`, shown if SSH never answers.
bcvk ephemeral run -d --rm -K --console --name "$VM" --memory 8G --vcpus 4 \
  --karg systemd.wants=sshd.service "$IMAGE" >/dev/null
# --rm races this removal; never let cleanup replace the exit status.
trap 'podman rm -f -t0 --ignore "$VM" >/dev/null 2>&1 || true' EXIT
# Everything after the VM name is the remote command: bcvk takes no ssh options.
ssh_vm() { timeout 180 bcvk ephemeral ssh "$VM" -- "$@"; }

deadline=$((SECONDS + TIMEOUT))
until timeout 20 bcvk ephemeral ssh "$VM" -- true >/dev/null 2>&1; do
  if ((SECONDS >= deadline)); then
    echo "FAIL VM answers SSH within ${TIMEOUT}s"
    podman logs --tail 40 "$VM" 2>&1 | sed 's/^/     /'
    exit 1
  fi
  sleep 2
done

check() {
  local out
  # On a non-zero exit bcvk adds its own error to stderr; keep only the VM's.
  if out=$(ssh_vm "{ $2; } 2>&1" 2>/dev/null); then
    echo "ok   $1"
  else
    echo "FAIL $1"
    [[ -z $out ]] || printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
  fi
}

. test/runtime-checks.sh

exit $fail
