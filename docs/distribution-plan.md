# Distribution plan — one-liner project creation (curl | bash / irm | iex)

> Working document created 2026-09-13, following the `docs/enhancement-plan.md`
> convention. It turns the agreed distribution decision into executable phases.
> **Status: not started.** Everything under "Decisions already made" is settled
> with the repo owner — implementing agents follow it as spec and do NOT
> relitigate; if a decision proves technically impossible, stop and report
> instead of substituting a different approach.

## Status overview

| Phase | Scope | Status |
|-------|-------|--------|
| D1 | ADR-0001 + release process doc + CONTRIBUTING releases section | **Done** |
| D2 | `scripts/bootstrap.{sh,ps1}` + T0 parity/tamper gate + `docs/testing.md` | **Done** |
| D3 | README + AGENTS.md alignment with the new entry point | **Done** |
| D4 | First release cut `v0.1.0` (checksums, one-liner verification) | **Owner action — not an agent phase** |

Legend: Pending → In progress → **Done (`<commit>`)** or Skipped (reason).
Executing agents update their own phase status in this file as the last step
before committing. Phases run sequentially (D1 → D2 → D3 → D4).

## Problem and goal

Today a consumer must: (1) clone this catalog, (2) `cd` into it, (3) pick the
right init script for their shell, (4) run it, (5) live with the leftover
clone. Goal: **one command from any directory, no catalog clone**, while the
tested init contract stays the single source of truth. The clone-then-run
flow remains documented as the fallback (offline use; locked-down corporate
environments).

## Decisions already made (spec, not suggestions)

1. **Approach:** `curl | bash` (Git Bash/WSL/macOS/Linux) and `irm | iex`
   (PowerShell) one-liners are the **default** documented entry point, backed
   by a new thin `scripts/bootstrap.{sh,ps1}` that **fetches and delegates** —
   it never reimplements template logic. `init-project.{sh,ps1}` remain the
   only implementation of the init contract.
2. **Rejected alternatives** (record fully in ADR-0001, do not revisit):
   dotnet scaffolding CLI (requires .NET SDK; would fork the merge logic),
   cookiecutter/copier/yeoman as generator (same forking problem; copier's
   update story contradicts the self-contained-projects house rule),
   GitHub "Use this template" (copies the whole catalog, runs no
   substitution), brew/scoop + static binary (deferred — second channels
   around the same bootstrap), devcontainer (wrong direction).
3. **Deferred, not rejected:** `npm create` wrapper vendoring the catalog at
   publish time (create-vite model) — explicitly out of scope for this plan;
   ADR-0001 records it as the sanctioned follow-up.
4. **Pin the payload, not the installer:** the one-liner fetches
   `bootstrap.{sh,ps1}` from `main` (thin, reviewed, instantly fixable), but
   the catalog tarball the bootstrap downloads is **pinned to a release tag
   by default and verified against the release's `checksums.txt`**. A fully
   pinned form (versioned raw URL + explicit `--ref/--sha256`) is documented
   for maximum reproducibility.
5. **Interactivity (owner decision):** if arguments are not passed on the
   one-liner, the user **selects them one by one** in the installer. No new
   prompt code: `bootstrap.sh` redirects the delegate's stdin from
   `/dev/tty` when stdin is a pipe, which engages `init-project.sh`'s
   existing first-run chooser (tier → provider → engine → name → dest). In
   PowerShell, console stdin survives `iex`, and `init-project.ps1` already
   prompts for missing mandatory params (`-Tier`/`-Name`/`-Dest`) plus the
   provider `Read-Host` loop — nothing to build.
6. **Versioning (owner decision):** semver. **MAJOR** = breaking change to
   generated project structure/behavior, **or** adopting a tofu/terraform/
   terragrunt major whose changes break generated configs. **MINOR** =
   additive capability, new tokens, version-pin bumps that keep generated
   projects valid (they change output bytes, not behavior). **PATCH** =
   fixes with no intentional generated-output change. Trunk-based is
   unchanged: tags are cut directly on `main`; there are no release branches.
7. **Strict by default, escape hatches explicit:** default mode (latest
   release) MUST fail if `checksums.txt` is missing. `--ref <tag>` without
   `--sha256` tries `checksums.txt` from that release, else fails.
   `--ref <branch|sha>` (moving target) skips verification with a loud
   warning. `--sha256` always wins when given.
8. **Scope guard:** this work adds NO template changes. Tier folders,
   `docs/conventions.md`, `docs/placeholders.md`, and both init scripts stay
   untouched — `tests/gen-manifests.sh` must produce **zero diff**. The
   bootstrap is catalog-level only; new docs are catalog-only and are NOT
   copied into generated projects (house rule 5 preserved). Because no
   conventions.md change is involved, the all-four-tiers-same-commit rule
   does not trigger (state this justification inside ADR-0001).

## Constraints for executing agents

- House rule 4: LF endings (gitattributes already covers new `*.sh`/`*.ps1`),
  PowerShell **5.1**-compatible syntax in `bootstrap.ps1` — no `??`, no
  ternary, no `?.`; `Invoke-WebRequest -UseBasicParsing`; force TLS 1.2 via
  `[Net.ServicePointManager]::SecurityProtocol = ... -bor 3072`.
- Mirror the existing scripts' style: `set -euo pipefail`, `error: …` to
  stderr, header comment as usage doc, `trap` in ps1 like `init-project.ps1`.
- **Piped-script caveat:** `bootstrap.sh` may run via `curl | bash`, where
  `$0` is `bash` and the script body is stdin — so unlike `init-project.sh`
  it must NOT implement `usage()` by `sed`-ing its own file header; print
  usage from a heredoc/echo. Same for `bootstrap.ps1` under `iex`
  (`$MyInvocation.MyCommand.Path` is empty — never depend on its own path).
- Error messages must be actionable (e.g. no-release-yet must suggest
  `--ref main` or the clone fallback).
- Propagate the init script's exit code; clean the temp dir unless `--keep`.

## Phase D1 — Decision record + release process (docs only)

Files: `docs/adr/0001-one-liner-installer.md` (new), `docs/release-process.md`
(new), `CONTRIBUTING.md` (edit). No code.

**ADR-0001 skeleton** (lightweight MADR-ish; sections: Status / Date /
Context / Decision / Alternatives considered / Consequences / Deferred):

- Context: the 5-step clone flow; the deciding constraint that
  `init-project.{sh,ps1}` locate `templates/` + `docs/` via `REPO_ROOT`
  relative to the script, so any remote entry point must materialize the
  catalog first; the merge logic (per-tier providers/ rules, tier-03 marker
  injection, CI resolution, token sweep) is golden-manifest-tested and must
  not be duplicated.
- Decision: fetch-and-delegate bootstrap as the one-liner backend; the
  sub-decisions #1–#8 above verbatim-ish (pin-the-payload, checksums.txt,
  /dev/tty interactivity, semver incl. tool-major rule, strict-by-default).
- Alternatives: each rejected approach with its failing criteria (use the
  C1 steps / C2 prerequisites / C3 parity / C4 contract reuse / C5 pinning /
  C6 maintenance / C7 trust / C8 update-story rubric from the research note;
  keep the table small — one row per alternative, verdict + primary failing
  criterion).
- Consequences: bootstrap must stay thin (enforced by the D2 parity gate);
  catalog docs gain `adr/` + `release-process.md` (catalog-only, not copied
  into projects); tier-scoped justification for touching no tiers (house
  rule 1 exception note).
- Deferred: `npm create` vendored wrapper; brew/scoop channel; static binary.

**`docs/release-process.md`** must define:

- Semver rules (decision #6) with one example each of MAJOR/MINOR/PATCH.
- Trunk-based note: annotated tag on `main`, no release branches, never
  re-point a pushed tag.
- The `checksums.txt` **format contract** the bootstrap parses: exactly one
  line, `<sha256>␠␠catalog.tar.gz` (lowercase hex, two spaces — the default
  `sha256sum catalog.tar.gz > checksums.txt` output).
- Release checklist (exact commands — also used by Phase D4):
  1. `main` green: `tests/run-in-docker.sh` (or `run-all.sh`) zero FAIL.
  2. `git tag -a vX.Y.Z -m "…"` + `git push origin vX.Y.Z`.
  3. `curl -fL -o catalog.tar.gz https://github.com/marshmary/iac/archive/refs/tags/vX.Y.Z.tar.gz`
  4. `sha256sum catalog.tar.gz > checksums.txt` (verify format contract).
  5. Create the GitHub Release for the tag and attach `checksums.txt`
     (web UI or `gh release create vX.Y.Z checksums.txt --notes "…"`).
  6. Smoke-test both one-liners from a scratch directory outside the repo
     (default mode — no `--ref`), including the interactive no-flags form.
  7. If this is the first release: remove the README interim note (D3).
- Renovate interplay: pin bumps arrive as grouped PRs; merging one that
  changes generated output ships in the next MINOR at least.

**CONTRIBUTING.md**: add a short `## Releases` section after "Before
committing": pointer to `docs/release-process.md`, the semver summary in two
lines, "tags are cut on `main` by the repo owner; agents never tag or push
releases", and `checksums.txt` is mandatory on every release.

Verification for D1: docs read coherently; no other file touched.

## Phase D2 — Bootstrap scripts + parity gate (the core)

Files: `scripts/bootstrap.sh` (new), `scripts/bootstrap.ps1` (new),
`tests/run-all.sh` (edit), `tests/run-all.ps1` (edit), `docs/testing.md`
(edit). Templates and init scripts untouched.

### bootstrap.sh — full spec

Header comment = usage doc (but usage printed from a heredoc, see
constraint). Flags (bootstrap consumes these, forwards everything else):

| Flag | Meaning |
|------|---------|
| `--ref <tag\|branch\|sha>` | catalog ref to fetch (default: latest published release) |
| `--sha256 <hash>` | verify tarball against this hash (overrides checksums.txt) |
| `--source <dir\|tar.gz>` | use a local catalog copy — offline/testing; skips ref+sha |
| `--keep` | keep the extracted temp dir and print its path |

Flow:

1. Parse own flags; collect the rest as `INIT_ARGS` (validated later by the
   init script — bootstrap never interprets `-t/-p/-n/...`).
2. Resolve source:
   - `--source <dir>` → `SRC_DIR=<dir>` directly.
   - `--source <tar.gz>` → extract into a fresh `mktemp -d`; if `--sha256`
     also given, verify first (`sha256sum` compare, fail hard on mismatch).
   - remote (default): `REF=${REF:-$(resolve latest)}` where resolve-latest
     = `curl -fsSI https://github.com/marshmary/iac/releases/latest`, parse
     the `Location:` header, strip everything through `/tag/` → tag. No
     releases yet (404) → die with the actionable message (decision #7 +
     interim note). Tarball URL:
     `https://github.com/marshmary/iac/archive/<ref>.tar.gz` (valid for tag,
     branch or sha). Verification per decision #7 matrix; default mode also
     prints `fetched <ref> (sha256 verified)` before delegating.
3. Extract, then locate the payload root: the tarball unpacks to a single
   top-level `iac-<something>/` — **detect it** (exactly one directory in
   the temp dir), never hardcode the name.
4. Delegate: run `"$SRC_DIR/scripts/init-project.sh" "${INIT_ARGS[@]}"`.
   Stdin handling (decision #5): if `[ -t 0 ]` → plain run; elif `/dev/tty`
   is openable → append `< /dev/tty` so the built-in chooser prompts
   one-by-one; elif INIT_ARGS is empty → die explaining to pass flags or run
   from a terminal (mirrors init's own non-TTY behavior).
5. Cleanup temp unless `--keep` (then print the kept path); exit with the
   init script's exit code.

Dependencies: bash, curl, tar, sha256sum — all present in Git Bash, macOS,
and Linux. No other tools; never invoke tofu/terraform (engine-agnostic —
house rule 3 spirit).

### bootstrap.ps1 — full spec

Same flags as PS parameters: `[string]$Ref`, `[string]$Sha256`,
`[string]$Source`, `[switch]$Keep`, plus
`[Parameter(ValueFromRemainingArguments = $true)][string[]]$InitArgs`.
`[CmdletBinding()]`, `$ErrorActionPreference = 'Stop'`, `trap` like
`init-project.ps1`. TLS 1.2 forced (see constraints). Differences from the
sh side:

- Latest-release resolve without the GitHub API (rate limits): raw
  `[System.Net.HttpWebRequest]` with `AllowAutoRedirect = $false`, read the
  `Location` header from the `WebException.Response` (302 throws on 5.1) —
  works identically on 5.1 and 7.
- Downloads via `Invoke-WebRequest -UseBasicParsing`; extraction via
  `tar -xzf` (`tar.exe` ships with Windows 10 1803+; guard with
  `Get-Command tar` and fail with a clear message if absent).
- Hash: `Get-FileHash -Algorithm SHA256`, compare case-insensitively.
- Interactivity needs nothing: `& "$srcDir\scripts\init-project.ps1"
  @InitArgs` — empty `InitArgs` lets PowerShell prompt mandatory params
  one-by-one (decision #5). No `/dev/tty` concept involved.
- Temp under `$env:TEMP` with a random suffix; cleanup
  `Remove-Item -Recurse -Force -ErrorAction SilentlyContinue`.

Documented one-liner forms (these exact strings go in the README in D3):

```
# Git Bash / WSL / macOS / Linux (NOT inside PowerShell — see README warning)
curl -fsSL https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.sh | bash -s -- -t 01 -p aws -n my-app -d ../my-app

# PowerShell 5.1+ (works in Windows PowerShell and pwsh)
Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.ps1) } -Tier 01 -Provider aws -Name my-app -Dest ..\my-app"
```

Flagless variants (interactive chooser / mandatory-param prompts) are the
same strings minus the trailing arguments.

### Parity gate — run-all.{sh,ps1} additions (T0 level, zero network)

Insert after the existing `T0/pins` check, before the tier loop. Build the
local catalog tarball from the **working tree** (NOT `git archive HEAD` —
uncommitted work must not false-fail parity):

```sh
tar -czf "$tmp/catalog.tar.gz" --exclude=.git --exclude=tests/scratch \
  --exclude=playground/projects -C "$REPO_ROOT" .
```

Three checks (each its own `result` line; skip-if-absent for `tar`/
`sha256sum`/`tar.exe` like other T0 tools, so the docker matrix and CLI-less
hosts still pass):

1. **`T0/bootstrap` "tarball+dir parity = direct init"** —
   `bootstrap.sh --source catalog.tar.gz -t 01 -p aws -n parity-check -d A
   --no-git` AND `bootstrap.sh --source "$REPO_ROOT" -t 02 -p azure -n
   parity-check -d B --no-git` (dir branch), each tree-compared (`diff -r`)
   against a direct `init-project.sh` run with identical flags. Same `-n`
   on both sides (the name is substituted into files); `--no-git` avoids
   `.git` noise.
2. **`T0/bootstrap` "sha mismatch rejected"** — copy the tarball, append one
   byte, run with `--sha256 <hash-of-good-tarball>`; bootstrap must exit
   non-zero.
3. Same two checks mirrored in `run-all.ps1` (`tar.exe`, `Get-FileHash`,
   `git`-less). PS tree compare: file list + per-file hash or content
   compare (reuse the manifest-compare normalization style).

Notes for the gate: the remote path (latest-release resolve + checksums.txt
fetch) is deliberately NOT in the matrix (network + a published release
don't exist in CI); `docs/release-process.md` step 6 covers it manually at
release time. Golden manifests are unaffected (no template changes) —
`gen-manifests.sh` must show zero diff.

**docs/testing.md**: extend the T0 row with "bootstrap parity (tarball +
dir source = direct init; sha mismatch rejected)" and add a short
"Bootstrap gate" paragraph: what it proves (the one-liner entry cannot fork
the init contract), that it runs offline via `--source`, and that the
remote path is release-checklist territory.

Verification for D2 (before claiming done): `bash -n scripts/*.sh
tests/*.sh`; PowerShell parse check on both new/edited ps1;
`tests/gen-manifests.sh` → zero diff; `tests/run-all.sh` green (T0 at
minimum; full matrix if CLIs/docker exist) with the two new T0/bootstrap
lines PASS; a manual end-to-end in Git Bash AND in `powershell.exe`:
`bootstrap --source <local tarball> -t 01 -p aws -n smoke -d <tmp> --no-git`
succeeds, and the same via `--source <repo dir>`; tamper case exits non-zero
in both shells.

## Phase D3 — README + AGENTS alignment

Files: `README.md`, `AGENTS.md`. Keep tier-level files untouched (their
AGENTS.md ship into projects — different audience).

**README.md**:

- Rewrite `## Quickstart` to lead with the two one-liners (exact strings
  from D2), each with a one-line caption; flagless = interactive chooser
  note; a short "what happens" line (downloads the latest published
  release, verifies sha256 against the release's checksums.txt, runs the
  same tested init script; see `docs/adr/0001…` + `docs/release-process.md`).
- A visible warning box: inside PowerShell, `curl` is an alias for
  `Invoke-WebRequest` — PowerShell users must use the `Invoke-Expression`
  form; the `curl | bash` line is for Git Bash/WSL/macOS/Linux only.
- Bootstrap options line: `--ref`, `--sha256`, `--source`, `--keep`
  (forwarded init flags as today).
- **Interim note (delete at v0.1.0, D4 step 7):** until the first release
  is published the default mode has nothing to resolve — append
  `--ref main` (sh) / `-Ref main` (ps1) to the one-liners.
- Demote today's clone-then-run block to `### Fallback — clone the catalog`
  (offline / restricted environments), content unchanged.
- Repo map: `scripts/` line gains `bootstrap.{sh,ps1}`; `docs/` line gains
  `adr/`, `release-process.md`, `distribution-plan.md`.
- "Future extensions": the copier/cookiecutter entry is now decided —
  replace with a pointer to ADR-0001 (rejected; `npm create` wrapper is the
  recorded follow-up). Infracost stays as-is.

**AGENTS.md**:

- Repo map: add `scripts/bootstrap.{sh,ps1}` — "thin fetch-and-delegate
  one-liner entry; must contain NO template logic (parity-gated)".
- Init-script contract section: one sentence — bootstrap is an entry
  wrapper around this contract, never a second implementation.
- Verification protocol: note the T0 bootstrap parity/tamper gate is part
  of `run-all` (steps 1–2 globs already cover the new files).
- "Where new content goes": add "New distribution entry point → keep
  bootstrap thin + parity gate in run-all + `docs/testing.md`".

Verification for D3: docs-only; grep that no stale clone-first phrasing
remains in README's quickstart; the two one-liner strings match D2 verbatim.

## Phase D4 — First release cut (OWNER, not agents)

Agents stop after D3. The owner executes the checklist in
`docs/release-process.md` for `v0.1.0`, then removes the README interim
note. Recorded here so it stays visible; nobody automates it.

## Commit plan (trunk-based, one concern each; never push)

1. `docs(adr): adopt one-liner installer via fetch-and-delegate bootstrap (ADR-0001)`
   - adr/0001: decision + rejected alternatives + deferred npm create
   - release-process: semver incl. tool-major rule, tag-on-main checklist, checksums contract
   - contributing: releases section pointing at the process
2. `feat(scripts): bootstrap.{sh,ps1} one-liner entry + T0 parity gate`
   - bootstrap: fetch pinned release tarball, sha256 gate, /dev/tty chooser passthrough, --source/--keep
   - run-all.{sh,ps1}: T0/bootstrap parity + sha-tamper checks (offline via --source)
   - testing.md: T0 row + bootstrap gate section
3. `docs: align README and agent guide with the one-liner distribution`
   - README: one-liner quickstart, PowerShell curl-alias warning, clone demoted to fallback
   - AGENTS.md: repo map + thin-bootstrap rule + parity gate in protocol

Each commit body ends with a `Verified:` line (CONTRIBUTING rule 5) using
the actual run-all summary. Update this file's status table in the same
commit as each phase lands.

## Sequencing notes

D1 first (the ADR records what D2 implements — including the interim
no-release behavior, which D2 must code and D3 must document). D2 is the
only phase with behavior; its gate must be green before D3 documents the
UX. D4 depends on everything merged and is human-only. If the parity gate
ever fails in CI with no relevant change, suspect the tarball excludes list
first (anything init copies from the repo root must not be excluded).
