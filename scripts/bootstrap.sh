#!/usr/bin/env bash
# bootstrap.sh — one-liner installer for this template catalog.
#
# Fetches a pinned catalog release, verifies its sha256, then delegates to
# the tested scripts/init-project.sh. This script contains NO template logic;
# the T0 parity gate in tests/run-all.sh fails the moment it forks the
# contract (docs/testing.md "Bootstrap gate", docs/adr/0001).
#
# Usage (piped, the documented one-liner):
#   curl -fsSL https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.sh \
#     | bash -s -- [bootstrap flags] [init-project flags]
# Usage (from a clone):
#   scripts/bootstrap.sh --ref vX.Y.Z -t 01 -p aws -n my-app -d ../my-app
#
# Piped-mode notes: under `curl | bash`, $0 is bash and this file is not on
# disk, so usage is printed from a heredoc (never sed-ed from $0), and the
# init script's interactive chooser is fed via /dev/tty (stdin is the pipe).
set -euo pipefail

REPO_SLUG="marshmary/iac"
RELEASE_BASE="https://github.com/${REPO_SLUG}/releases"
ARCHIVE_BASE="https://github.com/${REPO_SLUG}/archive"
TARBALL_NAME="catalog.tar.gz"

usage() {
  cat <<'EOF'
bootstrap.sh — instantiate an IaC project without cloning the catalog.

  curl -fsSL https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.sh | bash -s -- [flags]
  scripts/bootstrap.sh [--ref TAG] [--sha256 HEX] [--source DIR|TGZ] [--keep] [init-project flags]

bootstrap flags (everything else is forwarded to scripts/init-project.sh):
  --ref <tag|branch|sha>   catalog ref to fetch (default: latest published release)
  --sha256 <hex>           verify the tarball against this hash (overrides checksums.txt)
  --source <dir|tar.gz>    use a local catalog copy — offline/testing; overrides --ref
  --keep                   keep the extracted payload and print its path

verification policy (strict by default):
  default / --ref vX.Y.Z   sha256 verified against the release's checksums.txt;
                           a missing checksums.txt is a hard error
  --sha256                 verbatim hash check, wins over checksums.txt
  --ref <branch|sha>       moving target: verification skipped with a warning
EOF
}

die() { echo "error: $*" >&2; exit 1; }

sha256_of() { # $1 = file -> lowercase hex digest, empty when no hashing tool
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then # macOS ships shasum, not sha256sum
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r "$1" | cut -d' ' -f1
  else
    echo ""
  fi
}

resolve_latest_tag() { # follows /releases/latest's 302 to the current tag
  local loc tag
  loc="$(curl -fsSI -o /dev/null -w '%{redirect_url}' "${RELEASE_BASE}/latest" 2>/dev/null)" || {
    echo "error: could not resolve the latest release — none published yet?" >&2
    echo "  fix: add --ref main to the one-liner, or clone the catalog:" >&2
    echo "  git clone https://github.com/${REPO_SLUG}.git && scripts/init-project.sh -h" >&2
    exit 1
  }
  tag="${loc##*/tag/}"
  [ -n "$tag" ] && [ "$tag" != "$loc" ] || die "unexpected /releases/latest redirect: ${loc:-<empty>}"
  printf '%s' "$tag"
}

checksums_hash_for() { # $1 = tag -> catalog.tar.gz hash from that release (empty if absent)
  curl -fsSL "${RELEASE_BASE}/download/$1/checksums.txt" 2>/dev/null \
    | grep -E "^[0-9a-fA-F]{64}[[:space:]]+\*?${TARBALL_NAME}\$" \
    | head -n1 | cut -d' ' -f1 || true
}

is_tag_ref() { # release convention: vX.Y.Z (+ optional prerelease suffix)
  printf '%s' "$1" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+([-._][0-9A-Za-z.-]+)?$'
}

verify_hash() { # $1 = file, $2 = expected hex
  local got
  got="$(sha256_of "$1")"
  [ -n "$got" ] || die "no sha256 tool found (need sha256sum, shasum or openssl)"
  [ "$(printf '%s' "$got" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$2" | tr 'A-Z' 'a-z')" ] \
    || die "sha256 mismatch for $1: got $got, expected $2"
}

REF="" SHA256_ARG="" SOURCE="" KEEP=0
INIT_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) [ $# -ge 2 ] || die "--ref needs a value"; REF="$2"; shift 2 ;;
    --sha256) [ $# -ge 2 ] || die "--sha256 needs a value"; SHA256_ARG="$2"; shift 2 ;;
    --source) [ $# -ge 2 ] || die "--source needs a value"; SOURCE="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) INIT_ARGS+=("$1"); shift ;; # unknown flags are init-project's problem, not ours
  esac
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/iac-bootstrap.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

TARBALL="" SRC_DIR=""

if [ -n "$SOURCE" ]; then
  if [ -d "$SOURCE" ]; then
    SRC_DIR="$SOURCE"
  elif [ -f "$SOURCE" ]; then
    TARBALL="$SOURCE"
    [ -z "$SHA256_ARG" ] || verify_hash "$TARBALL" "$SHA256_ARG"
    echo "==> using local tarball $SOURCE (no remote verification requested)" >&2
  else
    die "--source is neither a directory nor a file: $SOURCE"
  fi
else
  if [ -n "$REF" ]; then
    FETCH_REF="$REF"
  else
    FETCH_REF="$(resolve_latest_tag)"
  fi
  echo "==> fetching ${REPO_SLUG}@${FETCH_REF}" >&2
  TARBALL="$WORK/$TARBALL_NAME"
  curl -fsSL -o "$TARBALL" "${ARCHIVE_BASE}/${FETCH_REF}.tar.gz" \
    || die "could not download ${ARCHIVE_BASE}/${FETCH_REF}.tar.gz"
  EXPECTED=""
  if [ -n "$SHA256_ARG" ]; then
    EXPECTED="$SHA256_ARG"
  elif [ -z "$REF" ] || is_tag_ref "$FETCH_REF"; then
    # default mode or an explicit vX.Y.Z tag: strict — checksums.txt must exist
    EXPECTED="$(checksums_hash_for "$FETCH_REF")"
    [ -n "$EXPECTED" ] || die "release $FETCH_REF has no checksums.txt — refusing an unverified install.
  fix: pass --sha256 explicitly, use --ref main (unverified, moving target), or clone the catalog."
  else
    echo "warning: --ref $FETCH_REF is a moving target; skipping sha256 verification" >&2
  fi
  if [ -n "$EXPECTED" ]; then
    verify_hash "$TARBALL" "$EXPECTED"
    echo "==> fetched $FETCH_REF (sha256 verified)" >&2
  else
    echo "==> fetched $FETCH_REF (UNVERIFIED)" >&2
  fi
fi

if [ -n "$TARBALL" ] && [ -z "$SRC_DIR" ]; then
  EXTRACT="$WORK/extract"
  mkdir -p "$EXTRACT"
  tar -xzf "$TARBALL" -C "$EXTRACT" || die "tar extraction failed for $TARBALL"
  # GitHub release tarballs wrap everything in a single top-level directory
  # (iac-<ref>/); the parity gate's plain `tar -C <repo> .` tarball does not.
  top_all="$(find "$EXTRACT" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  top_dirs="$(find "$EXTRACT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  if [ "$top_all" = 1 ] && [ "$top_dirs" = 1 ]; then
    SRC_DIR="$(find "$EXTRACT" -mindepth 1 -maxdepth 1 -type d)"
  else
    SRC_DIR="$EXTRACT"
  fi
fi

INIT="$SRC_DIR/scripts/init-project.sh"
[ -f "$INIT" ] || die "fetched catalog has no scripts/init-project.sh at: $SRC_DIR"

set +e
CODE=0
if [ -t 0 ]; then
  bash "$INIT" ${INIT_ARGS[@]+"${INIT_ARGS[@]}"} || CODE=$?
elif : 2>/dev/null < /dev/tty; then
  # stdin is a pipe (curl | bash): re-attach the delegate's stdin to the
  # terminal so init-project.sh's one-by-one first-run chooser can prompt.
  bash "$INIT" ${INIT_ARGS[@]+"${INIT_ARGS[@]}"} < /dev/tty || CODE=$?
elif [ "${#INIT_ARGS[@]}" -gt 0 ]; then
  bash "$INIT" ${INIT_ARGS[@]+"${INIT_ARGS[@]}"} < /dev/null || CODE=$?
else
  echo "error: no terminal available for the interactive chooser — pass init flags explicitly (scripts/init-project.sh -h)" >&2
  CODE=1
fi
set -e

if [ "$KEEP" = 1 ]; then
  echo "==> bootstrap payload kept at: $WORK (catalog: $SRC_DIR)" >&2
  trap - EXIT
fi
exit "$CODE"
