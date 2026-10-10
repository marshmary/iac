#!/usr/bin/env bash
# localize.sh — point a generated project at the local floci emulators
# (playground/compose.yml). Called by playground/up.sh and tests/t6-emulators.sh;
# also runnable standalone.
#
# What changes per cloud (templates are never touched — only the generated
# copy under playground/projects/ or tests/scratch/):
#   aws   the S3 `backend` block gets endpoint + use_path_style + the three
#         `skip_*` flags, and `use_lockfile` is flipped to false: floci does
#         not document S3 conditional writes (If-None-Match), which native
#         lockfile locking requires — see the "gotchas" section of
#         playground/README.md. The `aws` provider additionally gets
#         s3_use_path_style (tiers 01/02; Terragrunt tiers ship the provider
#         block commented out).
#   azure the azurerm `backend` block is pointed at floci-az (Azurite
#         wire-compatible): storage_account_name -> devstoreaccount1,
#         endpoint + account access_key added, container_name made per-tier
#         (tfstate-01..04) so the shared emulator account never mixes tiers'
#         state. The ARM resource plane is not emulated — azure starter
#         resources stay offline-validate.
#   gcp   nothing to patch: the gcs backend honors STORAGE_EMULATOR_HOST, so
#         wiring is purely environment — see the env hints printed at the end
#         and playground/state-bootstrap/fake-gcp-credentials.json.
#
# All patches are idempotent: an already-localized file is detected via its
# marker and skipped, so re-running up.sh never injects anything twice.
#
# Usage: localize.sh <project-dir> <tier> <cloud>
#   tier  01|02|03|04
#   cloud aws|azure|gcp  (tier 04 also accepts: all)
set -euo pipefail

proj="${1:?project dir}"; tier="${2:?tier}"; cloud="${3:?cloud: aws|azure|gcp|all}"

FLOCI_AWS_ENDPOINT="http://localhost:4566"
FLOCI_AZ_ACCOUNT="devstoreaccount1"
FLOCI_AZ_KEY="Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
FLOCI_AZ_ENDPOINT="http://localhost:4577/$FLOCI_AZ_ACCOUNT"

# ---------------------------------------------------------------------------
# AWS
# ---------------------------------------------------------------------------
patch_s3_backend() { # <file> — marker: use_path_style
  local f="$1" tmp
  [ -f "$f" ] || return 0
  grep -qF "use_path_style" "$f" && return 0
  tmp="$(mktemp)"
  awk -v ep="$FLOCI_AWS_ENDPOINT" '
    /^[[:space:]]*use_lockfile[[:space:]]*=/ {
      line = $0; sub(/= true/, "= false", line); print line
      match($0, /^[[:space:]]*/); ind = substr($0, 1, RLENGTH)
      print ind "endpoint                    = \"" ep "\""
      print ind "use_path_style              = true"
      print ind "skip_credentials_validation = true"
      print ind "skip_requesting_account_id  = true"
      print ind "skip_metadata_api_check     = true"
      next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

patch_aws_provider() { # <file> — marker: s3_use_path_style (tiers 01/02)
  local f="$1" tmp
  [ -f "$f" ] || return 0
  grep -qF "s3_use_path_style" "$f" && return 0
  tmp="$(mktemp)"
  awk '
    /^[[:space:]]*skip_metadata_api_check[[:space:]]*=/ {
      print
      match($0, /^[[:space:]]*/); ind = substr($0, 1, RLENGTH)
      print ind "s3_use_path_style           = true"
      next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# ---------------------------------------------------------------------------
# Azure
# ---------------------------------------------------------------------------
# Scoped to the `backend "azurerm"` block: the tier 03/04 root.hcl files carry
# plenty of other locals, so replacements only apply between the backend
# opener and its closing brace.
patch_azurerm_backend() { # <file> — marker: devstoreaccount1
  local f="$1" tmp
  [ -f "$f" ] || return 0
  grep -qF "$FLOCI_AZ_ACCOUNT" "$f" && return 0
  tmp="$(mktemp)"
  awk -v acct="$FLOCI_AZ_ACCOUNT" -v akey="$FLOCI_AZ_KEY" \
      -v ep="$FLOCI_AZ_ENDPOINT" -v ctr="tfstate-$tier" '
    /backend "azurerm"/ { inb = 1 }
    inb && /^[[:space:]]*storage_account_name[[:space:]]*=/ {
      match($0, /^[[:space:]]*/); ind = substr($0, 1, RLENGTH)
      print ind "storage_account_name = \"" acct "\""; next
    }
    inb && /^[[:space:]]*container_name[[:space:]]*=/ {
      match($0, /^[[:space:]]*/); ind = substr($0, 1, RLENGTH)
      print ind "container_name       = \"" ctr "\""; next
    }
    inb && /^[[:space:]]*key[[:space:]]*=/ && !done {
      print
      match($0, /^[[:space:]]*/); ind = substr($0, 1, RLENGTH)
      print ind "endpoint             = \"" ep "\""
      print ind "access_key           = \"" akey "\""
      done = 1; next
    }
    inb && /^[[:space:]]*\}[[:space:]]*$/ { inb = 0 }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
localize_cloud() { # $1 dir, $2 tier, $3 cloud
  local dir="$1" t="$2" c="$3"
  case "$c" in
    aws)
      if [ "$t" = 01 ]; then
        patch_s3_backend "$dir/backend.tf"; patch_aws_provider "$dir/provider.tf"
      elif [ "$t" = 02 ]; then
        local e
        for e in "$dir"/envs/*/; do
          [ -d "$e" ] || continue
          patch_s3_backend "$e/backend.tf"; patch_aws_provider "$e/provider.tf"
        done
      elif [ "$t" = 03 ]; then
        patch_s3_backend "$dir/root.hcl"
      else
        patch_s3_backend "$dir/platforms/aws/root.hcl"
      fi
      ;;
    azure)
      if [ "$t" = 01 ]; then
        patch_azurerm_backend "$dir/backend.tf"
      elif [ "$t" = 02 ]; then
        local e
        for e in "$dir"/envs/*/; do
          [ -d "$e" ] || continue
          patch_azurerm_backend "$e/backend.tf"
        done
      elif [ "$t" = 03 ]; then
        patch_azurerm_backend "$dir/root.hcl"
      else
        patch_azurerm_backend "$dir/platforms/azure/root.hcl"
      fi
      ;;
    gcp)
      : # env-only: STORAGE_EMULATOR_HOST + GOOGLE_APPLICATION_CREDENTIALS
      ;;
  esac
}

clouds="$cloud"
[ "$tier" = 04 ] && [ "$cloud" = all ] && clouds="aws azure gcp"

for c in $clouds; do
  localize_cloud "$proj" "$tier" "$c"
done

echo "localized tier $tier cloud(s): $clouds"
case " $clouds " in
  *" gcp "*)
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    echo "  gcp env: export STORAGE_EMULATOR_HOST=http://localhost:4588"
    echo "           GOOGLE_APPLICATION_CREDENTIALS=$script_dir/state-bootstrap/fake-gcp-credentials.json"
    ;;
esac
