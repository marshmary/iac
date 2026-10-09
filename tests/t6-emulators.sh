#!/usr/bin/env bash
# t6-emulators.sh — the T6 stage (docs/testing.md): full local lifecycle
# against the floci emulator trio — AWS :4566, Azure :4577, GCP :4588.
#
# What it proves, per cloud:
#   aws   a REAL tier-01 project (localized by playground/localize.sh) does
#         backend init + starter aws_s3_bucket apply + destroy against floci.
#   azure a minimal probe (terraform_data + azurerm backend) round-trips
#         state through floci-az blob storage (the ARM plane is not emulated,
#         so azure starter resources are deliberately absent from the probe).
#   gcp   the same probe shape with a gcs backend round-trips state through
#         floci-gcp (env-wired: STORAGE_EMULATOR_HOST + fake credentials).
#
# Opt-in because it needs Docker + an engine + image pulls:
#   IAC_T6=1 tests/run-all.sh     # the matrix runner invokes this script
#   tests/t6-emulators.sh         # standalone
#   IAC_T6_KEEP=1 ...             # keep the stack up afterwards (debugging)
#
# Absent prerequisites are SKIP-with-reason (never red) so the default
# no-cloud pyramid and the docker runner (which has no docker socket) stay
# green; genuine emulator failures are loud FAILs.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$REPO_ROOT/tests/scratch/t6"
COMPOSE="$REPO_ROOT/tests/docker-compose.emulators.yml"
NAME="demo-app"

FLOCI_AWS="http://localhost:4566"
FLOCI_AZ_URL="http://localhost:4577"
FLOCI_AZ_ACCOUNT="devstoreaccount1"
FLOCI_AZ_KEY="Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
FLOCI_GCP="http://localhost:4588"

PASS=0; FAIL=0; SKIP=0
have() { command -v "$1" >/dev/null 2>&1; }
result() { # $1 status, $2 label, $3 detail
  case "$1" in
    PASS) PASS=$((PASS+1)); printf 'PASS  %s %s\n' "$2" "$3" ;;
    FAIL) FAIL=$((FAIL+1)); printf 'FAIL  %s %s\n' "$2" "$3" ;;
    SKIP) SKIP=$((SKIP+1)); printf 'SKIP  %s %s\n' "$2" "$3" ;;
  esac
}

ENGINE=""
if have tofu; then ENGINE=tofu; elif have terraform; then ENGINE=terraform; fi
RUNNER=""
if have docker; then RUNNER=docker; elif have podman; then RUNNER=podman; fi
[ -n "$RUNNER" ] && ! "$RUNNER" compose version >/dev/null 2>&1 && RUNNER=""

if [ "${IAC_T6:-0}" != "1" ]; then
  result SKIP "T6/emulators" "opt-in only (set IAC_T6=1; needs docker + engine)"
  echo "=== T6 summary: $PASS pass, $FAIL fail, $SKIP skip ==="
  exit 0
fi

gate=0
[ -z "$ENGINE" ] && { result SKIP "T6/emulators" "no engine (tofu/terraform) installed"; gate=1; }
[ -z "$RUNNER" ] && { result SKIP "T6/emulators" "no docker/podman compose"; gate=1; }
have curl || { result SKIP "T6/emulators" "curl not installed"; gate=1; }
if [ "$gate" -eq 1 ]; then
  echo "=== T6 summary: $PASS pass, $FAIL fail, $SKIP skip ==="
  exit 0
fi

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/.terraform-plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR" 2>/dev/null || true

mkdir -p "$SCRATCH" && rm -rf "$SCRATCH"/*

teardown() {
  if [ "${IAC_T6_KEEP:-0}" = "1" ]; then
    echo "T6: keeping the emulator stack up (IAC_T6_KEEP=1)"
  else
    "$RUNNER" compose -f "$COMPOSE" down -v >/dev/null 2>&1 || true
  fi
  # keep scratch on failure for debugging, wipe it on success
  [ "$FAIL" -eq 0 ] && rm -rf "$SCRATCH" || true
}
trap teardown EXIT

# wait_http <url>: any HTTP response (even 4xx) proves the listener is up.
wait_http() {
  local url="$1" i code
  for i in $(seq 1 60); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$url" 2>/dev/null || true)"
    [ "$code" != "000" ] && [ -n "$code" ] && return 0
    sleep 2
  done
  return 1
}

echo "=== T6: booting the floci trio ==="
"$RUNNER" compose -f "$COMPOSE" up -d >/dev/null 2>&1 \
  && result PASS "T6/emulators" "compose up -d" \
  || { result FAIL "T6/emulators" "compose up -d"; exit 1; }

wait_http "$FLOCI_AWS"    && result PASS "T6/emulators" "floci (aws) on :4566" \
                          || result FAIL "T6/emulators" "floci (aws) not listening after 120s"
wait_http "$FLOCI_AZ_URL" && result PASS "T6/emulators" "floci-az on :4577" \
                          || result FAIL "T6/emulators" "floci-az not listening after 120s"
wait_http "$FLOCI_GCP"    && result PASS "T6/emulators" "floci-gcp on :4588" \
                          || result FAIL "T6/emulators" "floci-gcp not listening after 120s"

aws_env() {
  export AWS_ENDPOINT_URL="$FLOCI_AWS" \
         AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
         AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
}

# ---------------------------------------------------------------------------
# AWS leg: real tier-01 project, full lifecycle
# ---------------------------------------------------------------------------
dest="$SCRATCH/aws"
if "$REPO_ROOT/scripts/init-project.sh" -t 01 -p aws -n "$NAME" -d "$dest" --no-git >/dev/null 2>&1; then
  "$REPO_ROOT/playground/localize.sh" "$dest" 01 aws >/dev/null 2>&1 || true

  bdir="$SCRATCH/aws-bucket"
  mkdir -p "$bdir" && cp "$REPO_ROOT/playground/state-bootstrap/main.tf" "$bdir/main.tf"
  if ( cd "$bdir" && aws_env \
       && "$ENGINE" init -backend=false -input=false >/dev/null 2>&1 \
       && "$ENGINE" apply -auto-approve -input=false -var "bucket=$NAME-tfstate" >/dev/null 2>&1 ); then
    result PASS "T6/aws" "state bucket bootstrap ($NAME-tfstate)"
    if ( cd "$dest" && aws_env \
         && "$ENGINE" init -input=false >/dev/null 2>&1 \
         && "$ENGINE" apply -auto-approve -input=false -var-file=dev.tfvars >/dev/null 2>&1 \
         && "$ENGINE" state list 2>/dev/null | grep -q aws_s3_bucket \
         && "$ENGINE" destroy -auto-approve -input=false -var-file=dev.tfvars >/dev/null 2>&1 ); then
      result PASS "T6/aws" "backend init + starter apply + destroy on floci"
    else
      result FAIL "T6/aws" "backend init + starter apply + destroy on floci (see tests/scratch/t6/aws)"
    fi
  else
    result FAIL "T6/aws" "state bucket bootstrap (see tests/scratch/t6/aws-bucket)"
  fi
else
  result FAIL "T6/aws" "init-project failed"
fi

# ---------------------------------------------------------------------------
# Azure leg: state-plane probe through floci-az blob
# ---------------------------------------------------------------------------
pdir="$SCRATCH/azure"
mkdir -p "$pdir"
cat > "$pdir/main.tf" <<'EOF'
resource "terraform_data" "probe" {}
EOF
cat > "$pdir/backend.tf" <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "t6-local"
    storage_account_name = "$FLOCI_AZ_ACCOUNT"
    container_name       = "tfstate-t6"
    key                  = "t6/probe.tfstate"
    endpoint             = "$FLOCI_AZ_URL/$FLOCI_AZ_ACCOUNT"
    access_key           = "$FLOCI_AZ_KEY"
  }
}
EOF
if "$REPO_ROOT/playground/state-bootstrap/az-container.sh" \
     "$FLOCI_AZ_URL" "$FLOCI_AZ_ACCOUNT" "$FLOCI_AZ_KEY" "tfstate-t6" >/dev/null 2>&1; then
  result PASS "T6/azure" "state container bootstrap (tfstate-t6)"
  if ( cd "$pdir" && "$ENGINE" init -input=false >/dev/null 2>&1 \
       && "$ENGINE" apply -auto-approve -input=false >/dev/null 2>&1 \
       && "$ENGINE" state list 2>/dev/null | grep -q terraform_data \
       && "$ENGINE" destroy -auto-approve -input=false >/dev/null 2>&1 ); then
    result PASS "T6/azure" "azurerm backend init/apply/destroy on floci-az"
  else
    result FAIL "T6/azure" "azurerm backend roundtrip (see tests/scratch/t6/azure)"
  fi
else
  result FAIL "T6/azure" "state container bootstrap"
fi

# ---------------------------------------------------------------------------
# GCP leg: state-plane probe through floci-gcp GCS
# ---------------------------------------------------------------------------
gdir="$SCRATCH/gcp"
mkdir -p "$gdir"
cat > "$gdir/main.tf" <<'EOF'
resource "terraform_data" "probe" {}
EOF
cat > "$gdir/backend.tf" <<EOF
terraform {
  backend "gcs" {
    bucket = "$NAME-tfstate"
    prefix = "t6"
  }
}
EOF
gcode="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST \
  -H "Authorization: Bearer floci" -H "Content-Type: application/json" \
  -d "{\"name\":\"$NAME-tfstate\"}" "$FLOCI_GCP/storage/v1/b?project=floci-local")"
case "$gcode" in
  200|409) result PASS "T6/gcp" "state bucket bootstrap ($NAME-tfstate)" ;;
  *)       result FAIL "T6/gcp" "state bucket bootstrap (HTTP $gcode)" ;;
esac
gcp_env() {
  export STORAGE_EMULATOR_HOST="$FLOCI_GCP" \
         GOOGLE_APPLICATION_CREDENTIALS="$REPO_ROOT/playground/state-bootstrap/fake-gcp-credentials.json"
}
if ( cd "$gdir" && gcp_env \
     && "$ENGINE" init -input=false >/dev/null 2>&1 \
     && "$ENGINE" apply -auto-approve -input=false >/dev/null 2>&1 \
     && "$ENGINE" state list 2>/dev/null | grep -q terraform_data \
     && "$ENGINE" destroy -auto-approve -input=false >/dev/null 2>&1 ); then
  result PASS "T6/gcp" "gcs backend init/apply/destroy on floci-gcp"
else
  result FAIL "T6/gcp" "gcs backend roundtrip (see tests/scratch/t6/gcp)"
fi

echo "=== T6 summary: $PASS pass, $FAIL fail, $SKIP skip ==="
[ "$FAIL" -eq 0 ]
