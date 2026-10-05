#!/usr/bin/env bash
# Build the image from the working tree into rootless podman storage.
#   scripts/build.sh
# No sudo, so an agent can run it unattended.
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${LOCAL_IMAGE:-localhost/chauvenity-os:local}
RECIPE=${RECIPE:-recipes/recipe.yml}
name=${IMAGE%:*}

previous=$(podman image inspect --format '{{.Id}}' "$IMAGE" 2>/dev/null || true)

# bluebuild prefers docker when it is installed, which builds in a buildx
# container, pulls the base again there and leaves the result where bcvk
# (podman) cannot see it. /tmp is a RAM-backed tmpfs, too small to stage in.
bluebuild build -B podman -R podman --tempdir /var/tmp "$RECIPE"

# bluebuild tags the image <name>:latest_<platform>, then wraps it in one
# manifest list per tag: latest, <date>, 44, <date>-44, <sha>-44. Keep the image
# alone, as $IMAGE: a tag bluebuild never writes, so the next build cannot
# clobber it. `manifest rm` drops a list and never the image inside it.
digest=$(podman manifest inspect "$name:latest" | jq -r '.manifests[0].digest')
podman tag "$name@$digest" "$IMAGE"
for ref in $(podman images --format '{{.Repository}}:{{.Tag}}' "$name" | grep -vxF "$IMAGE"); do
  if podman manifest exists "$ref"; then podman manifest rm "$ref"; else podman untag "$ref" "$ref"; fi >/dev/null
done

# The tags above kept every superseded ~17 GB build alive; this one is gone too.
current=$(podman image inspect --format '{{.Id}}' "$IMAGE")
if [[ -n $previous && $previous != "$current" ]]; then
  podman rmi --ignore "$previous" >/dev/null
fi
echo "built $IMAGE ($current)"
