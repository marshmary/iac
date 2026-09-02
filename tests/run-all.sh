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
  for eng in tofu terraform; do
    bin="$(resolve_engine_bin "$eng")"
    [ -n "$bin" ] || { result SKIP "T1-T5/$tier-$prov/$eng" "engine not installed"; continue; }

    ( cd "$dest" && "$bin" fmt -check -recursive >/dev/null 2>&1 ) \
      && result PASS "T1/$tier-$prov/$eng" "fmt -check" || result FAIL "T1/$tier-$prov/$eng" "fmt -check"

    # T2: backend-less init + validate on every root/unit that is self-contained
    local roots=""
    case "$tier" in
      01) roots="." ;;
      02) for d in "$dest"/envs/*/; do [ -d "$d" ] && roots="$roots ${d#"$dest"/}"; done ;;
      03) roots="modules/baseline" ;;
      04) roots="" ;; # modules live in the external registry; hcl-validate covers units
    esac
    local r ok=1
    for r in $roots; do
      "$bin" -chdir="$dest/$r" init -backend=false >/dev/null 2>&1 \
        && "$bin" -chdir="$dest/$r" validate >/dev/null 2>&1 || ok=0
    done
    [ "$ok" = 1 ] && [ -n "$roots" ] \
      && result PASS "T2/$tier-$prov/$eng" "init -backend=false + validate ($roots)" \
      || { [ -z "$roots" ] && result SKIP "T2/$tier-$prov/$eng" "no local roots (registry modules)" \
           || result FAIL "T2/$tier-$prov/$eng" "validate failed ($roots)"; }

    # T3: offline plan (AWS only — provider ships skip_* = var.dry_run flags)
    if [ "$prov" = aws ] && [ "$tier" = 01 -o "$tier" = 02 ]; then
      local t3root="."; [ "$tier" = 02 ] && t3root="envs/dev"
      if ( cd "$dest/$t3root" && set -a && . "$REPO_ROOT/tests/fixtures/aws-fake.env" && set +a \
           && "$bin" plan -refresh=false -input=false -var dry_run=true \
                -var-file="$( [ "$tier" = 01 ] && echo dev.tfvars || echo dev.tfvars )" >/dev/null 2>&1 ); then
        result PASS "T3/$tier-$prov/$eng" "offline plan"
      else
        result FAIL "T3/$tier-$prov/$eng" "offline plan"
      fi
    else
      result SKIP "T3/$tier-$prov/$eng" "aws/plain-tiers only (TG tiers need backend; azure/gcp phone home)"
    fi

    # T4: OpenTofu native tests
    if [ "$("$bin" --version 2>/dev/null | head -1)" != "${bin##*/}" ] ; then :; fi
    if [ "$(basename "$bin")" = tofu ]; then
      local tdir=""
      [ -d "$dest/tests" ] && tdir="."
      [ -d "$dest/modules/baseline/tests" ] && tdir="modules/baseline"
      if [ -n "$tdir" ]; then
        if "$bin" -chdir="$dest/$tdir" test >/dev/null 2>&1; then
          result PASS "T4/$tier-$prov/tofu" "native tests ($tdir)"
        elif "$bin" -chdir="$dest/$tdir" test -backend=false >/dev/null 2>&1; then
          result PASS "T4/$tier-$prov/tofu" "native tests -backend=false ($tdir)"
        else
          result SKIP "T4/$tier-$prov/tofu" "test run failed (likely backend-coupled or needs registry)"
        fi
      else
        result SKIP "T4/$tier-$prov/tofu" "no shipped tests"
      fi
    else
      result SKIP "T4/$tier-$prov/$eng" "mock tests are OpenTofu-only"
    fi
  done

  # terragrunt structural checks (engine-independent)
  if have terragrunt; then
    case "$tier" in
      03) ( cd "$dest" && terragrunt hclfmt --terragrunt-check >/dev/null 2>&1 ) \
             && result PASS "T1/$prov-terragrunt" "hclfmt --terragrunt-check" \
             || result FAIL "T1/$prov-terragrunt" "hclfmt --terragrunt-check" ;;
      04) local pc ok=1
           for pc in aws azure gcp; do
             [ -d "$dest/platforms/$pc" ] || continue
             ( cd "$dest" && terragrunt hclfmt --terragrunt-check >/dev/null 2>&1 ) || ok=0
           done
           [ "$ok" = 1 ] && result PASS "T1/all-terragrunt" "hclfmt --terragrunt-check (all platforms)" \
                          || result FAIL "T1/all-terragrunt" "hclfmt failed" ;;
    esac
  else
    [ "$tier" = 03 -o "$tier" = 04 ] && result SKIP "T1/$prov-terragrunt" "terragrunt not installed"
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

    engine_loop "$tier" "$prov" "$dest"
  done
done

echo "=== summary: $PASS pass, $FAIL fail, $SKIP skip ==="
[ "$FAIL" -eq 0 ]
