#!/usr/bin/env bash
# check-pins.sh — T0-level pin-consistency gate (docs/testing.md).
#
# Engine pins must move atomically: the per-tier version files, the runner
# image's Dockerfile ARGs, and docs/engine-duality.md must all name the SAME
# versions. This check needs no CLIs and fails on the first drift it finds.
#
#   tests/check-pins.sh              # repo gate (wired into run-all.{sh,ps1})
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIERS="01-solo 02-small-team 03-team-terragrunt 04-large-terragrunt"
fails=0
# fail() writes to stderr: tier_pin/dockerfile_arg stdout is command-
# substituted, so diagnostics must not mix into the captured value.
fail() { echo "FAIL: $*" >&2; fails=1; }

# tier_pin <version-file> — echoes the pinned version and fails when the
# tiers that ship the file disagree with each other.
tier_pin() {
  local f t v want=""
  for t in $TIERS; do
    f="$REPO_ROOT/templates/$t/$1"
    [ -f "$f" ] || continue
    v="$(tr -d '[:space:]' < "$f")"
    if [ -z "$want" ]; then want="$v"
    elif [ "$v" != "$want" ]; then
      fail "$1 disagrees across tiers: '$want' vs '$v' ($t)"
      return
    fi
  done
  [ -n "$want" ] || fail "no tier ships $1"
  echo "$want"
}

# dockerfile_arg <ARG> — echoes the runner image's pinned default.
dockerfile_arg() {
  local v
  v="$(sed -n "s/^ARG $1=\(.*\)$/\1/p" "$REPO_ROOT/tests/docker/Dockerfile.runner")"
  if [ -z "$v" ]; then fail "ARG $1 missing in tests/docker/Dockerfile.runner"; fi
  echo "$v"
}

TF="$(tier_pin .terraform-version)"
TOFU="$(tier_pin .opentofu-version)"
TG="$(tier_pin .terragrunt-version)"   # tiers 03/04 only

check_eq() { # <label> <a> <b>
  if [ "$2" != "$3" ]; then fail "$1: '$2' != '$3' (pins must move atomically)"; fi
}

check_eq ".terraform-version vs Dockerfile TF_VERSION" "$TF" "$(dockerfile_arg TF_VERSION)"
check_eq ".opentofu-version  vs Dockerfile TOFU_VERSION" "$TOFU" "$(dockerfile_arg TOFU_VERSION)"
check_eq ".terragrunt-version vs Dockerfile TG_VERSION" "$TG" "$(dockerfile_arg TG_VERSION)"

# The engine-duality doc quotes the pins in prose — keep it honest too.
for pair in "Terraform:$TF" "OpenTofu:$TOFU"; do
  engine="${pair%%:*}"; ver="${pair#*:}"
  if ! grep -q "\`$ver\`" "$REPO_ROOT/docs/engine-duality.md"; then
    fail "docs/engine-duality.md does not quote the pinned $engine version \`$ver\`"
  fi
done

if [ "$fails" -ne 0 ]; then
  echo "pin drift detected — bump every location in the same commit (see docs/testing.md)."
  exit 1
fi
echo "pins consistent: terraform=$TF tofu=$TOFU terragrunt=$TG"
