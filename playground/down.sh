#!/usr/bin/env bash
# down.sh — tear down the playground emulators and their data volumes.
# The generated projects under playground/projects/ are LEFT IN PLACE so you can
# inspect logs/state; delete them explicitly if you want a fresh up.sh run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="$REPO_ROOT/playground/compose.yml"

RUNNER=""
if command -v docker >/dev/null 2>&1; then RUNNER=docker; elif command -v podman >/dev/null 2>&1; then RUNNER=podman; fi
if [ -n "$RUNNER" ] && ! "$RUNNER" compose version >/dev/null 2>&1; then RUNNER=""; fi

if [ -z "$RUNNER" ]; then
  echo "docker/podman not found — nothing to tear down." >&2
  exit 0
fi

echo ">>> $RUNNER compose down -v (removes localstack and azurite containers + volumes)"
"$RUNNER" compose -f "$COMPOSE" down -v

echo ""
echo "Emulators stopped and volumes removed."
echo "Generated projects remain at: $REPO_ROOT/playground/projects/"
echo "To clean them too:  rm -rf $REPO_ROOT/playground/projects/*"
