#!/usr/bin/env bash
# up.sh — build the disposable playground: instantiate all four tiers + boot
# the emulators + create the AWS state backend inside LocalStack.
#
# Everything it writes lives under playground/projects/ (gitignored). It never
# touches templates/, scripts/, tests/, or any generated project outside this
# folder. Logs go to playground/logs/ so the smoke output stays clean.
#
# Prerequisites: POSIX shell, docker/podman, and an IaC engine (tofu preferred,
# terraform fallback — same resolution as the project Taskfiles).
#
# Usage:
#   playground/up.sh                 # full: 4 tiers, aws provider, localstack
#   playground/up.sh --skip-emulators  # instantiate only (offline checks)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAY="$REPO_ROOT/playground"
PROJECTS="$PLAY/projects"
LOGS="$PLAY/logs"
COMPOSE="$PLAY/compose.yml"

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
  log "WARNING: no IaC engine (tofu/terraform) found — instantiate-only mode; apply steps will SKIP."
fi

# --- 1. instantiate all four tiers (disposable: wiped then recreated) ----------
log "=== instantiating tiers into $PROJECTS ==="
rm -rf "$PROJECTS"/01-solo "$PROJECTS"/02-small-team "$PROJECTS"/03-team-terragrunt "$PROJECTS"/04-large-terragrunt

init_project() { # $1 tier, $2 provider, $3 name, $4 subdir
  if "$REPO_ROOT/scripts/init-project.sh" -t "$1" -p "$2" -n "$3" -d "$PROJECTS/$4" --no-git >>"$LOGS/up.log" 2>&1; then
    result PASS "init tier $1 ($2) -> $4"
  else
    result FAIL "init tier $1 ($2) -> $4 (see logs/up.log)"
  fi
}

init_project 01 aws playground-01 01-solo
init_project 02 aws playground-02 02-small-team
init_project 03 aws playground-03 03-team-terragrunt
init_project 04 all playground-04 04-large-terragrunt

# --- 1b. localize to LocalStack (endpoint + path-style) -------------------------
# Injects LocalStack-only S3 backend/provider settings into the generated
# projects, scoped under projects/. Templates are never modified.
log "=== localizing projects to LocalStack ==="
"$PLAY/localize.sh" "$PROJECTS/01-solo" 01
"$PLAY/localize.sh" "$PROJECTS/02-small-team" 02
"$PLAY/localize.sh" "$PROJECTS/03-team-terragrunt" 03
"$PLAY/localize.sh" "$PROJECTS/04-large-terragrunt" 04
result PASS "localized 4 tiers (endpoint=localhost:4566, path-style S3)"

# --- 2. boot emulators ----------------------------------------------------------
RUNNER=""
if [ "$SKIP_EMULATORS" -ne 1 ]; then
  if have docker; then RUNNER=docker; elif have podman; then RUNNER=podman; fi
  if [ -n "$RUNNER" ] && ! "$RUNNER" compose version >/dev/null 2>&1; then RUNNER=""; fi
fi

if [ -n "$RUNNER" ]; then
  log "=== starting emulators ($RUNNER compose) ==="
  "$RUNNER" compose -f "$COMPOSE" up -d >>"$LOGS/up.log" 2>&1 \
    && result PASS "compose up -d" || result FAIL "compose up -d"

  log "--- waiting for LocalStack edge endpoint ---"
  ready=0
  for _ in $(seq 1 60); do
    if curl -fsS http://localhost:4566/_localstack/health >/dev/null 2>&1; then ready=1; break; fi
    sleep 2
  done
  if [ "$ready" -eq 1 ]; then
    result PASS "localstack healthy on :4566"
  else
    result FAIL "localstack not healthy after 120s (see logs/up.log)"
  fi
else
  log "NOTE: docker/podman not found (or --skip-emulators) — emulator + apply steps SKIP."
fi

# --- 3. bootstrap AWS state backend in LocalStack --------------------------------
if [ -n "$RUNNER" ] && [ -n "$ENGINE" ] && curl -fsS http://localhost:4566/_localstack/health >/dev/null 2>&1; then
  log "=== bootstrapping AWS state backend (bucket + lock table) in LocalStack ==="
  export AWS_ENDPOINT_URL="http://localhost:4566"
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"
  export AWS_REGION="us-east-1"
  export AWS_DEFAULT_REGION="us-east-1"
  export AWS_SKIP_SSM="true"

  for name in playground-01 playground-02 playground-03; do
    case "$name" in
      playground-01) sub=01-solo ;;
      playground-02) sub=02-small-team ;;
      playground-03) sub=03-team-terragrunt ;;
    esac
    bootdir="$PROJECTS/$sub/.playground-bootstrap"
    rm -rf "$bootdir"
    mkdir -p "$bootdir"
    cp "$PLAY/state-bootstrap/main.tf" "$bootdir/main.tf"

    # Idempotency: the LocalStack data volume persists across up.sh runs, so the
    # bucket/table may already exist. `tofu import` (best-effort, `|| true`) pulls
    # them into a fresh state so the later apply is a no-op instead of failing
    # with "ResourceInUseException: Table already exists". On a fresh volume the
    # imports find nothing and are harmless.
    ok=1
    ( cd "$bootdir" && "$ENGINE" init -backend=false -input=false >>"$LOGS/up.log" 2>&1 ) || ok=0
    ( cd "$bootdir" && "$ENGINE" import aws_s3_bucket.state "$name-tfstate" >>"$LOGS/up.log" 2>&1 ) || true
    ( cd "$bootdir" && "$ENGINE" import aws_s3_bucket_versioning.state "$name-tfstate" >>"$LOGS/up.log" 2>&1 ) || true
    ( cd "$bootdir" && "$ENGINE" import aws_dynamodb_table.lock "$name-tflock" >>"$LOGS/up.log" 2>&1 ) || true
    ( cd "$bootdir" && "$ENGINE" apply -auto-approve -input=false \
        -var "bucket=$name-tfstate" -var "table=$name-tflock" >>"$LOGS/up.log" 2>&1 ) || ok=0

    if [ "$ok" -eq 1 ]; then
      result PASS "state backend for $name (bucket=$name-tfstate, table=$name-tflock)"
    else
      result FAIL "state backend for $name (see logs/up.log)"
    fi
  done
else
  result SKIP "state backend bootstrap (no emulator/engine)"
fi

# --- 4. print cheat-sheet ----------------------------------------------------------
log ""
log "=== playground ready ==="
log "emulators:  ../playground/compose.yml   (localstack :4566, azurite :10000)"
log "projects:   $PROJECTS"
[ -n "$RUNNER" ] && log "creds:      AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1"
log ""
engine_note="$ENGINE"; [ -n "$engine_note" ] || engine_note="<none: install tofu or terraform>"
log "Next steps in each project (engine=$engine_note):"
log "  Tier 01  cd $PROJECTS/01-solo"
log "           task init-backend && task plan ENV=dev && task apply && task destroy ENV=dev"
log "  Tier 02  cd $PROJECTS/02-small-team"
log "           task init-backend ENV=dev && task plan ENV=dev && task apply ENV=dev"
log "  Tier 03  cd $PROJECTS/03-team-terragrunt"
log "           task init-backend ENV=dev && task plan ENV=dev && task apply ENV=dev"
log "  Tier 04  cd $PROJECTS/04-large-terragrunt   (baseline is provider-free; needs registry modules to do more)"
log "           task hcl-validate PLATFORM=aws ENV=dev COMPONENT=baseline"
log ""
log "Teardown:  playground/down.sh   (removes emulators + volumes; keep or delete projects/ as you like)"
