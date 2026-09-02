#!/usr/bin/env bash
# gen-manifests.sh — (re)generate golden file-tree manifests after a DELIBERATE
# structural change to a tier. Review the git diff of tests/manifests/ afterwards:
# an unexpected diff means a tier changed shape by accident.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$REPO_ROOT/tests/scratch"
MANIFESTS="$REPO_ROOT/tests/manifests"
mkdir -p "$MANIFESTS"

for tier in ${TIERS:-01 02 03 04}; do
  provs="aws azure gcp"; [ "$tier" = 04 ] && provs="all"
  for prov in $provs; do
    dest="$SCRATCH/manifest-$tier-$prov"
    "$REPO_ROOT/scripts/init-project.sh" -t "$tier" -p "$prov" -n demo-app -d "$dest" --no-git >/dev/null
    ( cd "$dest" && find . -type f | sort ) > "$MANIFESTS/$tier-$prov.txt"
    echo "wrote tests/manifests/$tier-$prov.txt ($(wc -l < "$MANIFESTS/$tier-$prov.txt") files)"
    rm -rf "$dest"
  done
done
echo "done — commit the manifest diff together with the tier change."
