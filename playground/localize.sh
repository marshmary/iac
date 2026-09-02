#!/usr/bin/env bash
# localize.sh — point a generated AWS project at LocalStack.
# Called by playground/up.sh; also runnable standalone.
#
# LocalStack serves all services on a single edge endpoint (localhost:4566).
# Two things must change in an otherwise-real generated project:
#   1. The S3 `backend` block needs `endpoint` + `use_path_style` + the three
#      `skip_*` flags, otherwise OpenTofu/Terraform resolves virtual-hosted
#      bucket URLs (bucket.localhost) that LocalStack cannot route.
#   2. The `aws` provider needs `s3_use_path_style = true` so the starter
#      `aws_s3_bucket` sends path-style URLs too (tiers 01/02 only — the
#      Terragrunt tiers' `generate` provider block ships commented out).
#
# Everything is written under the project's own directory (playground/projects/,
# gitignored). Templates/ are never touched.
#
# Usage: localize.sh <project-dir> <tier> [endpoint]
set -euo pipefail

proj="${1:?project dir}"; tier="${2:?tier}"; endpoint="${3:-http://localhost:4566}"

# patch_s3_backend <file>: insert LocalStack backend args inside the s3
# backend block, right after the dynamodb_table line (before its closing brace).
patch_s3_backend() {
  local f="$1" tmp
  [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  awk -v ins="    endpoint                    = \"$endpoint\"\n    use_path_style              = true\n    skip_credentials_validation = true\n    skip_requesting_account_id  = true\n    skip_metadata_api_check     = true" '
    /dynamodb_table/ { print; print ins; next }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# patch_provider <file>: add s3_use_path_style after the skip_metadata_api_check
# line (present in every tiers 01/02 provider block).
patch_provider() {
  local f="$1" tmp
  [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  awk '
    /skip_metadata_api_check/ { print; print "  s3_use_path_style           = true"; next }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

case "$tier" in
  01)
    patch_s3_backend "$proj/backend.tf"
    patch_provider "$proj/provider.tf"
    ;;
  02)
    for e in "$proj"/envs/*/; do
      [ -d "$e" ] || continue
      patch_s3_backend "$e/backend.tf"
      patch_provider "$e/provider.tf"
    done
    ;;
  03|04)
    # Terragrunt generates backend.tf per unit from root.hcl / platforms/*/root.hcl.
    # Insert the endpoint/path-style args into the generated backend `contents`.
    if [ "$tier" = 03 ]; then
      hcl_files=("$proj/root.hcl")
    else
      hcl_files=()
      for p in "$proj"/platforms/*/root.hcl; do [ -f "$p" ] && hcl_files+=("$p"); done
    fi
    for h in "${hcl_files[@]}"; do
      [ -f "$h" ] || continue
      tmp="$(mktemp)"
      awk -v ins="        endpoint                    = \"$endpoint\"\n        use_path_style              = true\n        skip_credentials_validation = true\n        skip_requesting_account_id  = true\n        skip_metadata_api_check     = true" '
        /dynamodb_table/ { print; print ins; next }
        { print }
      ' "$h" > "$tmp"
      mv "$tmp" "$h"
    done
    ;;
esac

echo "localized tier $tier -> endpoint=$endpoint"
