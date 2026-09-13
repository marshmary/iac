#!/usr/bin/env bash
# run-all.sh — the no-cloud test pyramid (docs/testing.md).
#
# Instantiates every tier x provider (x engine) into tests/scratch/ and runs
# T0..T5, skipping levels whose CLIs are absent. T0 (structural) always runs.
#
# Usage:
#   tests/run-all.sh                # full matrix, auto-detects tools
#   TIERS="01 03" tests/run-all.sh  # subset
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$REPO_ROOT/tests/scratch"
MANIFESTS="$REPO_ROOT/tests/manifests"
NAME="demo-app"
# shared provider cache: each provider downloads once per matrix run
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/.terraform-plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR" 2>/dev/null || true
PASS=0; FAIL=0; SKIP=0

have() { command -v "$1" >/dev/null 2>&1; }
result() { # $1 status, $2 label, $3 detail
  case "$1" in
    PASS) PASS=$((PASS+1)); printf 'PASS  %s %s\n' "$2" "$3" ;;
    FAIL) FAIL=$((FAIL+1)); printf 'FAIL  %s %s\n' "$2" "$3" ;;
    SKIP) SKIP=$((SKIP+1)); printf 'SKIP  %s %s\n' "$2" "$3" ;;
  esac
}

resolve_engine_bin() { # $1 = engine name -> echo binary path or empty
  if have "$1"; then command -v "$1"; elif [ "$1" = "tofu" ] && have terraform; then command -v terraform; else echo ""; fi
}

run_init() { # $1 tier, $2 provider, $3 dest -> 0/1
  rm -rf "$3"
  "$REPO_ROOT/scripts/init-project.sh" -t "$1" -p "$2" -n "$NAME" -d "$3" --no-git >/dev/null 2>&1
}

engine_loop() { # $1 tier, $2 provider, $3 dest — runs T1..T5 per available engine
  local tier="$1" prov="$2" dest="$3" eng bin

  # roots that are self-contained (shared by T1 tflint/checkov and T2
  # init/validate); engine-independent, computed once
  local roots=""
  case "$tier" in
    01) roots="." ;;
    02) for d in "$dest"/envs/*/; do [ -d "$d" ] && roots="$roots ${d#"$dest"/}"; done ;;
    03) roots="modules/baseline" ;;
    04) roots="modules-local/baseline" ;; # vendored provider-free module
  esac

  for eng in tofu terraform; do
    bin="$(resolve_engine_bin "$eng")"
    [ -n "$bin" ] || { result SKIP "T1-T5/$tier-$prov/$eng" "engine not installed"; continue; }

    ( cd "$dest" && "$bin" fmt -check -recursive >/dev/null 2>&1 ) \
      && result PASS "T1/$tier-$prov/$eng" "fmt -check" || result FAIL "T1/$tier-$prov/$eng" "fmt -check"

    if have tflint && [ -n "$roots" ]; then
      local r lok=1
      for r in $roots; do
        # env/module dirs don't see the project-root config by default
        ( cd "$dest/$r" && tflint --init --config="$dest/.tflint.hcl" >/dev/null 2>&1 ) || true # plugin fetch, best effort
        ( cd "$dest/$r" && tflint --config="$dest/.tflint.hcl" >/dev/null 2>&1 ) || lok=0
      done
      [ "$lok" = 1 ] && result PASS "T1/$tier-$prov/$eng" "tflint" || result FAIL "T1/$tier-$prov/$eng" "tflint"
    elif [ -n "$roots" ]; then
      result SKIP "T1/$tier-$prov/$eng" "tflint (not installed)"
    fi

    # T2: backend-less init + validate on every root/unit that is self-contained
    local r ok=1
    for r in $roots; do
      "$bin" -chdir="$dest/$r" init -backend=false >/dev/null 2>&1 \
        && "$bin" -chdir="$dest/$r" validate >/dev/null 2>&1 || ok=0
    done
    [ "$ok" = 1 ] && [ -n "$roots" ] \
      && result PASS "T2/$tier-$prov/$eng" "init -backend=false + validate ($roots)" \
      || { [ -z "$roots" ] && result SKIP "T2/$tier-$prov/$eng" "no local roots (registry modules)" \
           || result FAIL "T2/$tier-$prov/$eng" "validate failed ($roots)"; }

    # T3: offline plan (AWS only — provider ships skip_* = var.dry_run flags).
    # Runs in a copy with every backend.tf and .terraform dir removed: T2's
    # backend-less init would otherwise conflict with the real backend config,
    # and the point here is proving the CONFIGURATION plans offline, not the
    # state plumbing.
    if [ "$prov" = aws ] && { [ "$tier" = 01 ] || [ "$tier" = 02 ]; }; then
      local t3root="."; [ "$tier" = 02 ] && t3root="envs/dev"
      local t3copy="$SCRATCH/t3/$label-$eng"
      mkdir -p "$SCRATCH/t3"
      rm -rf "$t3copy" && cp -a "$dest" "$t3copy"
      find "$t3copy" -name backend.tf -delete
      find "$t3copy" -name .terraform.lock.hcl -delete
      find "$t3copy" -name .terraform -type d -prune -exec rm -rf {} +
      if ( cd "$t3copy/$t3root" && set -a && . "$REPO_ROOT/tests/fixtures/aws-fake.env" && set +a \
           && "$bin" init >/dev/null 2>&1 \
           && "$bin" plan -refresh=false -input=false -var dry_run=true -var-file=dev.tfvars >/dev/null 2>&1 ); then
        result PASS "T3/$tier-$prov/$eng" "offline plan (backend-stripped copy)"
      else
        result FAIL "T3/$tier-$prov/$eng" "offline plan (backend-stripped copy)"
      fi
      rm -rf "$t3copy"
    else
      result SKIP "T3/$tier-$prov/$eng" "aws/plain-tiers only (TG tiers need backend; azure/gcp phone home)"
    fi

    # T4: OpenTofu native tests
    if [ "$(basename "$bin")" = tofu ]; then
      local tdir=""
      [ -d "$dest/tests" ] && tdir="."
      [ -d "$dest/modules/baseline/tests" ] && tdir="modules/baseline"
      [ -d "$dest/modules-local/baseline/tests" ] && tdir="modules-local/baseline"
      if [ -n "$tdir" ]; then
        local t4pass=""
        if "$bin" -chdir="$dest/$tdir" test >/dev/null 2>&1; then
          t4pass="native tests ($tdir)"
        elif [ "$tdir" = "." ] && [ -f "$dest/backend.tf" ]; then
          # root tests with a real backend block: retry in a stripped copy
          local t4copy="$SCRATCH/t4/$label"
          mkdir -p "$SCRATCH/t4"
          rm -rf "$t4copy" && cp -a "$dest" "$t4copy"
          find "$t4copy" -name backend.tf -delete
          find "$t4copy" -name .terraform -type d -prune -exec rm -rf {} +
          if ( cd "$t4copy" && "$bin" init >/dev/null 2>&1 && "$bin" test >/dev/null 2>&1 ); then
            t4pass="native tests (backend-stripped copy)"
          fi
          rm -rf "$t4copy"
        fi
        if [ -n "$t4pass" ]; then
          result PASS "T4/$tier-$prov/tofu" "$t4pass"
        else
          result FAIL "T4/$tier-$prov/tofu" "shipped tests failed to run or assert"
        fi
      else
        result SKIP "T4/$tier-$prov/tofu" "no shipped tests"
      fi
    else
      result SKIP "T4/$tier-$prov/$eng" "mock tests are OpenTofu-only"
    fi
  done

  # T1: checkov security scan — engine-independent, so it runs ONCE per
  # tier x provider (the heavy python scan gains nothing from the second
  # engine pass). The tier's .checkov.yaml carries documented suppressions
  # (starter resources).
  if [ -n "$roots" ]; then
    if have checkov; then
      local r cok=1
      for r in $roots; do
        ( cd "$dest/$r" && checkov -d . --config-file "$dest/.checkov.yaml" >/dev/null 2>&1 ) || cok=0
      done
      [ "$cok" = 1 ] && result PASS "T1/$tier-$prov/checkov" "checkov" \
                     || result FAIL "T1/$tier-$prov/checkov" "checkov"
    else
      result SKIP "T1/$tier-$prov/checkov" "checkov not installed"
    fi
  fi

  # terragrunt structural checks (engine-independent)
  if have terragrunt; then
    case "$tier" in
      03) ( cd "$dest" && terragrunt hcl fmt --check >/dev/null 2>&1 ) \
             && result PASS "T1/$prov-terragrunt" "hcl fmt --check" \
             || result FAIL "T1/$prov-terragrunt" "hcl fmt --check" ;;
      04) local pc ok=1
           for pc in aws azure gcp; do
             [ -d "$dest/platforms/$pc" ] || continue
             ( cd "$dest/platforms/$pc" && terragrunt hcl fmt --check >/dev/null 2>&1 ) || ok=0
           done
           [ "$ok" = 1 ] && result PASS "T1/all-terragrunt" "hcl fmt --check (all platforms)" \
                          || result FAIL "T1/all-terragrunt" "hcl fmt failed" ;;
    esac
  else
    [ "$tier" = 03 -o "$tier" = 04 ] && result SKIP "T1/$prov-terragrunt" "terragrunt not installed"
  fi

  # T5: conftest policy unit tests (tier 04; inline mocks, no plan needed)
  if [ "$tier" = 04 ]; then
    if have conftest; then
      ( cd "$dest" && conftest verify --policy policy/ >/dev/null 2>&1 ) \
        && result PASS "T5/$tier" "conftest verify (policy unit tests)" \
        || result FAIL "T5/$tier" "conftest verify (policy unit tests)"
    else
      result SKIP "T5/$tier" "conftest not installed"
    fi
  fi

  # T5: conftest policy assertions (tier 04; requires a produced plan — T3-dependent)
  if [ "$tier" = 04 ]; then
    if have conftest; then
      if compgen -G "$dest/**/tfplan.json" >/dev/null; then
        ( cd "$dest" && find . -name tfplan.json -print0 | xargs -0 -n1 conftest test -p policy/ >/dev/null 2>&1 ) \
          && result PASS "T5/$tier" "conftest on plan json" || result FAIL "T5/$tier" "conftest on plan json"
      else
        result SKIP "T5/$tier" "no tfplan.json produced (T3 skipped for tier 04)"
      fi
    else
      result SKIP "T5/$tier" "conftest not installed"
    fi
  fi
}

echo "=== iac template test matrix ==="

# T0-level pin consistency (docs/testing.md): version files, runner ARGs and
# engine-duality docs must name the same engines/terragrunt versions.
"$REPO_ROOT/tests/check-pins.sh" >/dev/null 2>&1 \
  && result PASS "T0/pins" "version files = runner ARGs = engine-duality docs" \
  || result FAIL "T0/pins" "pin drift (run tests/check-pins.sh for details)"

# T0-level bootstrap parity (docs/testing.md "Bootstrap gate"): the one-liner
# entry (scripts/bootstrap.sh) must produce trees identical to direct init,
# and a corrupted tarball must be rejected on sha256 mismatch. Runs fully
# offline via --source; the remote path is release-checklist territory
# (docs/release-process.md step 6).
if have tar && { have sha256sum || have shasum; }; then
  bt="$SCRATCH/bootstrap"
  rm -rf "$bt"; mkdir -p "$bt"
  # tarball from the working tree (not git archive HEAD): uncommitted changes
  # must not false-fail parity
  tar -czf "$bt/catalog.tar.gz" --exclude=.git --exclude=tests/scratch \
      --exclude=playground/projects -C "$REPO_ROOT" .
  if have sha256sum; then
    good_hash="$(sha256sum "$bt/catalog.tar.gz" | cut -d' ' -f1)"
  else
    good_hash="$(shasum -a 256 "$bt/catalog.tar.gz" | cut -d' ' -f1)"
  fi
  bok=1
  "$REPO_ROOT/scripts/bootstrap.sh" --source "$bt/catalog.tar.gz" --sha256 "$good_hash" \
      -t 01 -p aws -n parity-check -d "$bt/tarball-A" --no-git >/dev/null 2>&1 || bok=0
  "$REPO_ROOT/scripts/bootstrap.sh" --source "$REPO_ROOT" \
      -t 02 -p azure -n parity-check -d "$bt/dir-B" --no-git >/dev/null 2>&1 || bok=0
  "$REPO_ROOT/scripts/init-project.sh" -t 01 -p aws -n parity-check -d "$bt/ref-A" --no-git >/dev/null 2>&1 || bok=0
  "$REPO_ROOT/scripts/init-project.sh" -t 02 -p azure -n parity-check -d "$bt/ref-B" --no-git >/dev/null 2>&1 || bok=0
  if [ "$bok" = 1 ] \
     && diff -r "$bt/tarball-A" "$bt/ref-A" >/dev/null 2>&1 \
     && diff -r "$bt/dir-B" "$bt/ref-B" >/dev/null 2>&1; then
    result PASS "T0/bootstrap" "tarball+dir parity = direct init"
  else
    result FAIL "T0/bootstrap" "bootstrap output differs from direct init"
  fi

  cp "$bt/catalog.tar.gz" "$bt/bad.tar.gz"
  printf 'x' >> "$bt/bad.tar.gz"
  if "$REPO_ROOT/scripts/bootstrap.sh" --source "$bt/bad.tar.gz" --sha256 "$good_hash" \
      -t 01 -p aws -n parity-check -d "$bt/tampered" --no-git >/dev/null 2>&1; then
    result FAIL "T0/bootstrap" "sha mismatch not rejected"
  else
    result PASS "T0/bootstrap" "sha mismatch rejected"
  fi
  rm -rf "$bt"
else
  result SKIP "T0/bootstrap" "tar or a sha256 tool not installed"
fi

for tier in ${TIERS:-01 02 03 04}; do
  provs="aws azure gcp"; [ "$tier" = 04 ] && provs="all"
  for prov in $provs; do
    dest="$SCRATCH/$tier-$prov"
    label="$tier-$prov"

    if ! run_init "$tier" "$prov" "$dest"; then
      result FAIL "T0/$label" "init-project failed"
      continue
    fi
    result PASS "T0/$label" "init + token sweep (enforced by init script)"

    manifest="$MANIFESTS/$label.txt"
    if [ -f "$manifest" ]; then
      if diff <( cd "$dest" && find . -type f | sort ) "$manifest" >/dev/null 2>&1; then
        result PASS "T0/$label" "golden manifest match"
      else
        result FAIL "T0/$label" "golden manifest drift (regen: tests/gen-manifests.sh)"
      fi
    else
      result SKIP "T0/$label" "no golden manifest (run tests/gen-manifests.sh)"
    fi

    if have task; then
      ( cd "$dest" && task --list >/dev/null 2>&1 ) \
        && result PASS "T1/$label/taskfile" "task --list parses" \
        || result FAIL "T1/$label/taskfile" "task --list failed"
    else
      result SKIP "T1/$label/taskfile" "task not installed"
    fi

    engine_loop "$tier" "$prov" "$dest"
  done
done

echo "=== summary: $PASS pass, $FAIL fail, $SKIP skip ==="
[ "$FAIL" -eq 0 ]
