#!/usr/bin/env bash
# up.sh — build the disposable playground: instantiate every tier x cloud +
# boot the floci emulator trio + create the state backends for all three
# clouds (AWS S3 buckets, Azure blob containers, GCS buckets).
#
# Everything it writes lives under playground/projects/ (gitignored). It never
# touches templates/, scripts/, tests/, or any generated project outside this
# folder. Logs go to playground/logs/ so the smoke output stays clean.
#
# Prerequisites: POSIX shell, docker/podman, curl, and an IaC engine (tofu
# preferred, terraform fallback — same resolution as the project Taskfiles).
# The engine is only needed for the AWS bucket bootstrap; the Azure/GCP
# bootstraps are plain curl.
#
# Usage:
#   playground/up.sh                   # full: 10 projects, floci trio, 3 state planes
#   playground/up.sh --skip-emulators  # instantiate + localize only (offline checks)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAY="$REPO_ROOT/playground"
PROJECTS="$PLAY/projects"
LOGS="$PLAY/logs"
COMPOSE="$PLAY/compose.yml"

FLOCI_AZ_URL="http://localhost:4577"
FLOCI_AZ_ACCOUNT="devstoreaccount1"
FLOCI_AZ_KEY="Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
FLOCI_GCP_URL="http://localhost:4588"

SKIP_EMULATORS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-emulators) SKIP_EMULATORS=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$PROJECTS" "$LOGS"
: > "$LOGS/up.log"

log() { printf '%s\n' "$*" | tee -a "$LOGS/up.log"; }

have() { command -v "$1" >/dev/null 2>&1; }

resolve_engine() {
  if have tofu; then echo tofu
  elif have terraform; then echo terraform
  else echo ""; fi
}

result() { # $1 status $2 label
  case "$1" in
    PASS) printf 'PASS  %s\n' "$2" | tee -a "$LOGS/up.log" ;;
    FAIL) printf 'FAIL  %s\n' "$2" | tee -a "$LOGS/up.log" ;;
    SKIP) printf 'SKIP  %s\n' "$2" | tee -a "$LOGS/up.log" ;;
  esac
}

ENGINE="$(resolve_engine)"
if [ -z "$ENGINE" ]; then
  log "WARNING: no IaC engine (tofu/terraform) found — the AWS bucket bootstrap will SKIP."
fi

# --- 1. instantiate every tier x cloud (disposable: wiped then recreated) ------
log "=== instantiating tiers into $PROJECTS ==="
rm -rf "$PROJECTS"/01-solo-* "$PROJECTS"/02-small-team-* \
       "$PROJECTS"/03-team-terragrunt-* "$PROJECTS"/04-large-terragrunt

init_project() { # $1 tier, $2 provider, $3 name, $4 subdir
  if "$REPO_ROOT/scripts/init-project.sh" -t "$1" -p "$2" -n "$3" -d "$PROJECTS/$4" --no-git >>"$LOGS/up.log" 2>&1; then
    result PASS "init tier $1 ($2) -> $4"
  else
    result FAIL "init tier $1 ($2) -> $4 (see logs/up.log)"
  fi
}

init_project 01 aws   playground-01-aws   01-solo-aws
init_project 01 azure playground-01-azure 01-solo-azure
init_project 01 gcp   playground-01-gcp   01-solo-gcp
init_project 02 aws   playground-02-aws   02-small-team-aws
init_project 02 azure playground-02-azure 02-small-team-azure
init_project 02 gcp   playground-02-gcp   02-small-team-gcp
init_project 03 aws   playground-03-aws   03-team-terragrunt-aws
init_project 03 azure playground-03-azure 03-team-terragrunt-azure
init_project 03 gcp   playground-03-gcp   03-team-terragrunt-gcp
init_project 04 all   playground-04       04-large-terragrunt

# --- 1b. localize to the floci emulators ----------------------------------------
# Injects emulator-only backend/provider settings into the generated projects
# (AWS endpoint + path-style + lockfile-off; Azure Azurite-compatible blob
# endpoint; GCP is env-only). Templates are never modified.
log "=== localizing projects to floci ==="
localize() { # $1 subdir, $2 tier, $3 cloud
  "$PLAY/localize.sh" "$PROJECTS/$1" "$2" "$3" >>"$LOGS/up.log" 2>&1
}
for c in aws azure gcp; do
  localize "01-solo-$c" 01 "$c"
  localize "02-small-team-$c" 02 "$c"
  localize "03-team-terragrunt-$c" 03 "$c"
done
localize 04-large-terragrunt 04 all
result PASS "localized 10 projects (aws :4566, azure :4577, gcp env-based)"

# --- 2. boot the floci emulator trio ---------------------------------------------
RUNNER=""
if [ "$SKIP_EMULATORS" -ne 1 ]; then
  if have docker; then RUNNER=docker; elif have podman; then RUNNER=podman; fi
  if [ -n "$RUNNER" ] && ! "$RUNNER" compose version >/dev/null 2>&1; then RUNNER=""; fi
fi

# wait_http <url>: any HTTP response (even 4xx) proves the listener is up;
# floci has no LocalStack-style health endpoint.
wait_http() {
  local url="$1" i code
  for i in $(seq 1 60); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$url" 2>/dev/null || true)"
    [ "$code" != "000" ] && [ -n "$code" ] && return 0
    sleep 2
  done
  return 1
}

if [ -n "$RUNNER" ]; then
  log "=== starting floci emulators ($RUNNER compose) ==="
  "$RUNNER" compose -f "$COMPOSE" up -d >>"$LOGS/up.log" 2>&1 \
    && result PASS "compose up -d" || result FAIL "compose up -d"

  log "--- waiting for the three emulator endpoints ---"
  wait_http "$FLOCI_AZ_URL"      && result PASS "floci-az listening on :4577" \
                                    || result FAIL "floci-az not listening after 120s"
  wait_http "$FLOCI_GCP_URL"     && result PASS "floci-gcp listening on :4588" \
                                    || result FAIL "floci-gcp not listening after 120s"
  wait_http "http://localhost:4566" && result PASS "floci (aws) listening on :4566" \
                                    || result FAIL "floci (aws) not listening after 120s"
else
  log "NOTE: docker/podman not found (or --skip-emulators) — emulator + bootstrap steps SKIP."
fi

EMULATORS_UP=0
if [ -n "$RUNNER" ] && curl -s -o /dev/null --max-time 2 "http://localhost:4566" 2>/dev/null; then
  EMULATORS_UP=1
fi

# --- 3a. bootstrap AWS state buckets in floci (:4566) -----------------------------
if [ "$EMULATORS_UP" -eq 1 ] && [ -n "$ENGINE" ]; then
  log "=== bootstrapping AWS state buckets (versioned) in floci ==="
  export AWS_ENDPOINT_URL="http://localhost:4566"
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"
  export AWS_REGION="us-east-1"
  export AWS_DEFAULT_REGION="us-east-1"

  aws_bucket() { # $1 bucket name, $2 owning project subdir
    local name="$1" sub="$2" bootdir ok
    bootdir="$PROJECTS/$sub/.playground-bootstrap"
    rm -rf "$bootdir"
    mkdir -p "$bootdir"
    cp "$PLAY/state-bootstrap/main.tf" "$bootdir/main.tf"

    # Idempotency: the floci data volume persists across up.sh runs, so the
    # bucket may already exist. `tofu import` (best-effort, `|| true`) pulls it
    # into a fresh state so the later apply is a no-op instead of failing with
    # "BucketAlreadyOwnedByYou". On a fresh volume the imports find nothing and
    # are harmless.
    ok=1
    ( cd "$bootdir" && "$ENGINE" init -backend=false -input=false >>"$LOGS/up.log" 2>&1 ) || ok=0
    ( cd "$bootdir" && "$ENGINE" import aws_s3_bucket.state "$name" >>"$LOGS/up.log" 2>&1 ) || true
    ( cd "$bootdir" && "$ENGINE" import aws_s3_bucket_versioning.state "$name" >>"$LOGS/up.log" 2>&1 ) || true
    ( cd "$bootdir" && "$ENGINE" apply -auto-approve -input=false \
        -var "bucket=$name" >>"$LOGS/up.log" 2>&1 ) || ok=0
    rm -rf "$bootdir"

    if [ "$ok" -eq 1 ]; then
      result PASS "aws state bucket $name ($sub)"
    else
      result FAIL "aws state bucket $name (see logs/up.log)"
    fi
  }

  aws_bucket playground-01-aws-tfstate 01-solo-aws
  aws_bucket playground-02-aws-tfstate 02-small-team-aws
  aws_bucket playground-03-aws-tfstate 03-team-terragrunt-aws
  aws_bucket playground-04-tfstate     04-large-terragrunt
else
  result SKIP "aws state bucket bootstrap (no emulator/engine)"
fi

# --- 3b. bootstrap Azure state containers in floci-az (:4577) ---------------------
if [ "$EMULATORS_UP" -eq 1 ] && have curl; then
  log "=== bootstrapping Azure state containers in floci-az ==="
  az_ok=1
  for t in 01 02 03 04; do
    "$PLAY/state-bootstrap/az-container.sh" "$FLOCI_AZ_URL" "$FLOCI_AZ_ACCOUNT" "$FLOCI_AZ_KEY" "tfstate-$t" \
      >>"$LOGS/up.log" 2>&1 || az_ok=0
  done
  [ "$az_ok" -eq 1 ] && result PASS "azure state containers tfstate-01..04" \
                     || result FAIL "azure state containers (see logs/up.log)"
else
  result SKIP "azure state container bootstrap (no emulator/curl)"
fi

# --- 3c. bootstrap GCS state buckets in floci-gcp (:4588) ------------------------
if [ "$EMULATORS_UP" -eq 1 ] && have curl; then
  log "=== bootstrapping GCS state buckets in floci-gcp ==="
  gcp_ok=1
  for b in playground-01-gcp-tfstate playground-02-gcp-tfstate \
           playground-03-gcp-tfstate playground-04-tfstate; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST \
      -H "Authorization: Bearer floci" -H "Content-Type: application/json" \
      -d "{\"name\":\"$b\"}" "$FLOCI_GCP_URL/storage/v1/b?project=floci-local")"
    case "$code" in
      200|409) log "  gcs bucket $b: ok ($code)" ;;
      *) log "  gcs bucket $b: unexpected HTTP $code"; gcp_ok=0 ;;
    esac
  done
  [ "$gcp_ok" -eq 1 ] && result PASS "gcs state buckets x4" \
                     || result FAIL "gcs state buckets (see logs/up.log)"
else
  result SKIP "gcs state bucket bootstrap (no emulator/curl)"
fi

# --- 4. print cheat-sheet ----------------------------------------------------------
log ""
log "=== playground ready ==="
log "emulators:  ../playground/compose.yml  (floci :4566, floci-az :4577, floci-gcp :4588)"
log "projects:   $PROJECTS"
[ -n "$RUNNER" ] && log "aws env:    AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1"
[ -n "$RUNNER" ] && log "gcp env:    STORAGE_EMULATOR_HOST=http://localhost:4588 GOOGLE_APPLICATION_CREDENTIALS=$PLAY/state-bootstrap/fake-gcp-credentials.json"
[ -n "$RUNNER" ] && log "azure env:  none needed - the localized azurerm backend carries its own access_key"
log ""
engine_note="$ENGINE"; [ -n "$engine_note" ] || engine_note="<none: install tofu or terraform>"
log "Next steps (engine=$engine_note):"
log "  AWS full apply (starter bucket + state backend):"
log "    cd $PROJECTS/01-solo-aws"
log "    AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 \\"
log "      task init-backend && task plan ENV=dev && task apply && task destroy ENV=dev"
log "  Azure/GCP (state plane only; starters are not emulated - offline validate):"
log "    cd $PROJECTS/01-solo-azure && task check"
log "    cd $PROJECTS/01-solo-gcp && STORAGE_EMULATOR_HOST=http://localhost:4588 \\"
log "      GOOGLE_APPLICATION_CREDENTIALS=$PLAY/state-bootstrap/fake-gcp-credentials.json task check"
log "  Terragrunt tiers (baseline is provider-free; state goes through each cloud's emulator):"
log "    cd $PROJECTS/03-team-terragrunt-aws && task init-backend ENV=dev && task plan ENV=dev"
log "    cd $PROJECTS/04-large-terragrunt && task hcl-validate PLATFORM=azure ENV=dev COMPONENT=baseline"
log ""
log "Teardown:  playground/down.sh   (removes emulators + volumes; keep or delete projects/ as you like)"
