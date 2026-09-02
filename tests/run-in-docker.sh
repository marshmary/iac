#!/usr/bin/env bash
# run-in-docker.sh — run the full test matrix inside the pinned runner
# container (tests/docker/Dockerfile.runner), regardless of what is installed
# on the host. Uses docker when available, else podman.
#
# Usage:
#   tests/run-in-docker.sh                      # full matrix (tests/run-all.sh)
#   tests/run-in-docker.sh tests/gen-manifests.sh
#   tests/run-in-docker.sh tofu fmt -recursive templates/01-solo
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="iac-test-runner:latest"

if command -v docker >/dev/null 2>&1; then
  RUNNER=docker
elif command -v podman >/dev/null 2>&1; then
  RUNNER=podman
else
  echo "error: neither docker nor podman found on PATH" >&2
  exit 1
fi

# Windows Git Bash: mixed-mode paths (C:/...) that docker/podman accept.
# All host paths are converted explicitly; MSYS_NO_PATHCONV then disables
# Git Bash's own mangling of the composite "-v host:/work" argument.
to_host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}
DOCKERFILE="$(to_host_path "${REPO_ROOT}/tests/docker/Dockerfile.runner")"
CONTEXT="$(to_host_path "${REPO_ROOT}/tests/docker")"
MOUNT="$(to_host_path "$REPO_ROOT")"

echo ">>> building ${IMAGE} (${RUNNER})"
MSYS_NO_PATHCONV=1 "$RUNNER" build -q -f "$DOCKERFILE" -t "$IMAGE" "$CONTEXT"

if [ $# -eq 0 ]; then set -- tests/run-all.sh; fi

echo ">>> running: $*"
MSYS_NO_PATHCONV=1 "$RUNNER" run --rm -v "${MOUNT}":/work -w /work "$IMAGE" "$@"
