#!/usr/bin/env bash
# init-project.sh — instantiate a new IaC project from a tier template.
#
# Usage:
#   scripts/init-project.sh -t <01|02|03|04> -p <aws|azure|gcp> -n <kebab-name> -d <dest-dir>
#                           [-e <tofu|terraform>] [--ci <github|gitlab|none>]
#                           [--region <region>] [--no-git] [--allow-tokens]
#
# What it does (the contract documented in AGENTS.md):
#   1. copies templates/<tier>/ to <dest>
#   2. merges the chosen cloud's providers/ layer (tier-specific rules)
#   3. copies shared docs (conventions, engine-duality, migrations) into <dest>/docs
#   4. substitutes __TOKEN__ placeholders (defaults in docs/placeholders.md)
#   5. fails if any __TOKEN__ survives (unless --allow-tokens)
#   6. keeps the CI skeleton you asked for (--ci github|gitlab; default none strips them)
#   7. git init (unless --no-git) and prints next steps
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

TIER="" PROVIDER="" NAME="" DEST="" ENGINE="tofu" REGION_OVERRIDE="" NO_GIT=0 ALLOW_TOKENS=0 CI_TARGET="none"
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tier) TIER="${2:?}"; shift 2 ;;
    -p|--provider) PROVIDER="${2:?}"; shift 2 ;;
    -n|--name) NAME="${2:?}"; shift 2 ;;
    -d|--dest) DEST="${2:?}"; shift 2 ;;
    -e|--engine) ENGINE="${2:?}"; shift 2 ;;
    --ci) CI_TARGET="${2:?}"; shift 2 ;;
    --region) REGION_OVERRIDE="${2:?}"; shift 2 ;;
    --no-git) NO_GIT=1; shift ;;
    --allow-tokens) ALLOW_TOKENS=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown flag: $1" >&2; usage ;;
  esac
done

# Interactive first-run chooser: fills required flags not given on the
# command line (tier -> provider -> engine -> name -> dest). Only engages on
# a TTY; piped/CI callers keep the plain usage error, so scripted behavior
# is unchanged.
if [ -z "$TIER" ] || [ -z "$NAME" ] || [ -z "$DEST" ]; then
  [ -t 0 ] || usage
  while :; do
    printf 'tier (01 solo / 02 small team / 03 team-terragrunt / 04 large-terragrunt): '
    IFS= read -r TIER
    case "$TIER" in 01|02|03|04) break ;; esac
    echo "  must be 01, 02, 03 or 04" >&2
  done
  if [ "$TIER" != "04" ] && [ -z "$PROVIDER" ]; then
    while :; do
      printf 'provider (aws/azure/gcp): '
      IFS= read -r PROVIDER
      case "$PROVIDER" in aws|azure|gcp) break ;; esac
      echo "  must be aws, azure or gcp" >&2
    done
  fi
  while :; do
    printf 'engine [tofu|terraform] (tofu): '
    IFS= read -r _engine_in
    [ -z "$_engine_in" ] && _engine_in="tofu"
    case "$_engine_in" in tofu|terraform) break ;; esac
    echo "  must be tofu or terraform" >&2
  done
  ENGINE="$_engine_in"
  while :; do
    printf 'project name (kebab-case slug): '
    IFS= read -r NAME
    [ -n "$NAME" ] || { echo "  must not be empty" >&2; continue; }
    printf '%s' "$NAME" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' && break
    echo "  must be kebab-case (a-z, 0-9, -), 1-63 chars, no leading/trailing hyphen" >&2
  done
  while [ -z "$DEST" ]; do
    printf 'destination directory: '
    IFS= read -r DEST
    [ -z "$DEST" ] && echo "  must not be empty" >&2
  done
fi

[ -n "$TIER" ] && [ -n "$NAME" ] && [ -n "$DEST" ] || usage
case "$TIER" in 01|02|03|04) ;; *) echo "error: -t must be 01, 02, 03 or 04" >&2; exit 1 ;; esac
case "$ENGINE" in tofu|terraform) ;; *) echo "error: -e must be tofu or terraform" >&2; exit 1 ;; esac
case "$CI_TARGET" in github|gitlab|none) ;; *) echo "error: --ci must be github, gitlab or none" >&2; exit 1 ;; esac
if [ "$TIER" != "04" ]; then
  case "$PROVIDER" in aws|azure|gcp) ;; *) echo "error: -p must be aws, azure or gcp (tier 04 keeps all platforms)" >&2; exit 1 ;; esac
else
  PROVIDER="all"
fi
echo "$NAME" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' || { echo "error: -n must be kebab-case (a-z, 0-9, -), 1-63 chars, no leading/trailing hyphen" >&2; exit 1; }

case "$TIER" in
  01) TIER_DIR="01-solo" ;;
  02) TIER_DIR="02-small-team" ;;
  03) TIER_DIR="03-team-terragrunt" ;;
  04) TIER_DIR="04-large-terragrunt" ;;
esac
SRC="$REPO_ROOT/templates/$TIER_DIR"
[ -d "$SRC" ] || { echo "error: template for tier $TIER not found: $SRC" >&2; exit 1; }

if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  echo "error: destination exists and is not empty: $DEST" >&2; exit 1
fi
case "$DEST" in
  "$REPO_ROOT"/tests/scratch/*) ;; # runner scratch — fine
  "$REPO_ROOT"/*) echo "note: creating project inside the template repo itself" >&2 ;;
esac

mkdir -p "$DEST"
cp -a "$SRC/." "$DEST/"

# --- tier-specific provider merge -------------------------------------------------
merge_provider_tests() { # providers/<cloud>/tests/ -> <dest>/tests/ (e.g. per-cloud mock test files)
  if [ -d "$DEST/providers/$PROVIDER/tests" ]; then
    mkdir -p "$DEST/tests"
    cp -a "$DEST/providers/$PROVIDER/tests/." "$DEST/tests/"
  fi
}

case "$TIER" in
  01)
    for src in "$DEST"/providers/$PROVIDER/*.tf; do
      [ -f "$src" ] || { echo "error: no provider .tf files for $PROVIDER" >&2; exit 1; }
      mv "$src" "$DEST/$(basename "$src")"
    done
    merge_provider_tests
    rm -rf "$DEST/providers"
    ;;
  02)
    for envdir in "$DEST"/envs/*/; do
      [ -d "$envdir" ] || continue
      envname="$(basename "$envdir")"
      for src in "$DEST"/providers/$PROVIDER/*.tf; do
        [ -f "$src" ] || { echo "error: no provider .tf files for $PROVIDER" >&2; exit 1; }
        sed "s/__ENV__/$envname/g" "$src" > "$envdir/$(basename "$src")"
      done
    done
    merge_provider_tests
    rm -rf "$DEST/providers"
    ;;
  03)
    marker_begin='# >>> CLOUD PROVIDER'
    marker_end='# <<< END CLOUD PROVIDER'
    [ -f "$DEST/providers/$PROVIDER/root-provider.hcl" ] || { echo "error: missing root-provider.hcl for $PROVIDER" >&2; exit 1; }
    awk -v mb="$marker_begin" -v me="$marker_end" -v inc="$DEST/providers/$PROVIDER/root-provider.hcl" '
      index($0, mb) { print; while ((getline line < inc) > 0) print line; close(inc); inblock=1; next }
      index($0, me) { inblock=0; print; next }
      !inblock { print }
    ' "$DEST/root.hcl" > "$DEST/root.hcl.tmp" && mv "$DEST/root.hcl.tmp" "$DEST/root.hcl"
    rm -rf "$DEST/providers"
    ;;
  04) : ;; # all platforms retained
esac

# --- shared docs copied into the generated project ---------------------------------
mkdir -p "$DEST/docs"
cp "$REPO_ROOT/docs/conventions.md" "$REPO_ROOT/docs/engine-duality.md" "$DEST/docs/"
cp -r "$REPO_ROOT/docs/migrations" "$DEST/docs/migrations"

# --- token substitution --------------------------------------------------------------
azure_sa="$(printf '%s' "$NAME" | tr -cd 'a-z0-9' | cut -c1-17)tfstate"

global_map=( "__PROJECT_NAME__=$NAME" )
cloud_region() {
  case "$1" in
    aws) echo "${REGION_OVERRIDE:-us-east-1}" ;;
    azure) echo "${REGION_OVERRIDE:-eastus}" ;;
    gcp) echo "${REGION_OVERRIDE:-us-central1}" ;;
  esac
}
map_for() { # $1 = cloud -> prints sed s/// expressions
  local c="$1"
  echo "-e s|__REGION__|$(cloud_region "$c")|g"
  case "$c" in
    aws)   echo "-e s|__STATE_BUCKET__|$NAME-tfstate|g" ;;
    azure) echo "-e s|__STATE_RESOURCE_GROUP__|$NAME-tfstate-rg|g" "-e s|__STATE_STORAGE_ACCOUNT__|$azure_sa|g" "-e s|__STATE_CONTAINER__|tfstate|g" ;;
    gcp)   echo "-e s|__STATE_BUCKET__|$NAME-tfstate|g" "-e s|__GCP_PROJECT__|$NAME-project|g" ;;
  esac
}

substitute() { # $1 = dir, rest = sed -e args
  local dir="$1"; shift
  local f
  while IFS= read -r -d '' f; do
    grep -Iq . "$f" 2>/dev/null || continue # skip binaries
    sed -i "$@" "$f"
  done < <(find "$dir" -type f -print0)
}

global_sed=()
for kv in "${global_map[@]}"; do global_sed+=( "-e" "s|${kv%%=*}|${kv#*=}|g" ); done

if [ "$TIER" = "04" ]; then
  # Global + cross-cloud registry tokens everywhere (accounts.hcl lives outside
  # platforms/); then per-cloud tokens under platforms/<cloud>/ only, where the
  # cloud-specific __REGION__ value is unambiguous. Account/subscription
  # tokens are per-env so dev and prod can differ; the distinct zero-defaults
  # force a conscious replacement before any real use.
  registry_sed=(
    -e "s|__AWS_ACCOUNT_ID_DEV__|000000000000|g"
    -e "s|__AWS_ACCOUNT_ID_PROD__|000000000001|g"
    -e "s|__AZURE_SUBSCRIPTION_ID_DEV__|00000000-0000-0000-0000-000000000000|g"
    -e "s|__AZURE_SUBSCRIPTION_ID_PROD__|00000000-0000-0000-0000-000000000001|g"
    -e "s|__GCP_PROJECT__|$NAME-project|g"
  )
  substitute "$DEST" "${global_sed[@]}" "${registry_sed[@]}"
  for c in aws azure gcp; do
    [ -d "$DEST/platforms/$c" ] || continue
    # shellcheck disable=SC2046
    substitute "$DEST/platforms/$c" $(map_for "$c")
  done
else
  # shellcheck disable=SC2046
  substitute "$DEST" "${global_sed[@]}" $(map_for "$PROVIDER")
fi

# --- self-test: no surviving tokens ---------------------------------------------------
if [ "$ALLOW_TOKENS" -ne 1 ]; then
  leftovers="$(grep -rEn '__[A-Z0-9_]+__' "$DEST" 2>/dev/null || true)"
  if [ -n "$leftovers" ]; then
    echo "error: unsubstituted tokens remain:" >&2
    echo "$leftovers" >&2
    exit 1
  fi
fi

# --- CI skeletons (opt-in: --ci github|gitlab; default none strips them) -----
# The local-first philosophy ships NO pipeline by default; the skeletons stay
# in the tier templates so a plain init never produces one unless asked.
case "$CI_TARGET" in
  github) rm -f "$DEST/.gitlab-ci.yml" ;;
  gitlab) rm -rf "$DEST/.github/workflows"; rmdir "$DEST/.github" 2>/dev/null || true ;;
  none)   rm -rf "$DEST/.github/workflows" "$DEST/.gitlab-ci.yml"; rmdir "$DEST/.github" 2>/dev/null || true ;;
esac

# --- engine preference + git -----------------------------------------------------------
printf '# local preferences (gitignored)\nIAC_ENGINE=%s\n' "$ENGINE" > "$DEST/.env"
if [ "$NO_GIT" -ne 1 ] && [ ! -d "$DEST/.git" ]; then
  git -C "$DEST" init -q
fi

# --- next steps -------------------------------------------------------------------------
tier_desc="templates/$TIER"
echo ""
echo "Initialized $NAME from $tier_desc (cloud: $PROVIDER, engine: $ENGINE)"
echo ""
echo "Next steps:"
echo "  1. cd $DEST"
echo "  2. review defaults you may want to change:"
case "$TIER" in
  01) echo "     - backend.tf (state bucket/keys from bootstrap/$PROVIDER.md)" ;;
  02) echo "     - envs/*/backend.tf (state bucket/keys from bootstrap/$PROVIDER.md)" ;;
  03) echo "     - root.hcl injected backend block (values from bootstrap/$PROVIDER.md)" ;;
  04) echo "     - common/accounts.hcl + common/regions.hcl (real ids) and platforms/*/root.hcl backends" ;;
esac
if [ "$TIER" = 04 ]; then
  echo "  3. follow platforms/<cloud>/bootstrap.md for each platform you will use"
else
  echo "  3. follow bootstrap/$PROVIDER.md to create the state backend"
fi
echo "  4. task engine-check && task check     # offline validation"
echo "  5. task init-backend && task plan$( [ "$TIER" != 01 ] && echo " ENV=dev" )$( [ "$TIER" = 04 ] && echo " PLATFORM=aws" ) && review"
echo "  6. task apply && commit the lockfile"
echo ""
echo "Agent guidance: AGENTS.md in the project root. Growth path: docs/migrations/."
