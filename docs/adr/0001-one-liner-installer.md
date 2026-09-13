# ADR-0001: one-liner installer via fetch-and-delegate bootstrap

## Status

Accepted (2026-09-13). Supersedes nothing; implementation tracked in
`docs/distribution-plan.md`.

## Context

Instantiating a project from this catalog currently requires five steps:
clone the catalog, `cd` into it, pick the init script for the shell, run it,
and live with the leftover clone. The goal is **one command from any
directory, no catalog clone** — the way `npm create`, `dotnet new`, and
Go/PNPM remote references feel — without shortening any step that decides
*which* template the user gets.

Two facts in the repo shape the solution space:

1. `scripts/init-project.{sh,ps1}` locate `templates/` and `docs/` via
   `REPO_ROOT` relative to their own file, so *any* remote entry point must
   materialize the catalog on disk before delegation can happen.
2. The init scripts are not thin. They implement the per-tier `providers/`
   merge table (copy-to-root for tier 01, per-env copy with `__ENV__`
   substitution for tier 02, marker injection into tier 03's `root.hcl`,
   per-platform substitution for tier 04), CI-skeleton resolution, shared-docs
   copying, and the fail-loudly token sweep — and that behavior is pinned by
   the golden manifests in `tests/manifests/`. Any second implementation of
   this logic can and will drift; the manifests only gate the path they run
   on.

## Decision

Ship a **fetch-and-delegate bootstrap** (`scripts/bootstrap.{sh,ps1}`) as the
backend of two documented one-liners — `curl … | bash` (Git Bash/WSL/macOS/
Linux) and `Invoke-Expression "& { $(irm …) }"` (PowerShell 5.1+) — and make
them the default entry point. The bootstrap contains **no template logic**:
it resolves a ref, fetches the catalog tarball, verifies it, extracts it to a
temp dir, and execs the existing init script with forwarded arguments. The
clone-then-run flow stays documented as the fallback (offline use, corporate
pipe-to-shell restrictions).

Sub-decisions (settled with the repo owner; implementing agents treat these
as spec):

1. **Pin the payload, not the installer.** The one-liner fetches the
   bootstrap script from `main` (it is thin, reviewed, and instantly
   fixable), but the catalog tarball is pinned to the **latest published
   release tag by default** and verified against that release's
   `checksums.txt`. A fully pinned form (versioned raw URL + explicit
   `--ref`/`--sha256`) is documented for maximum reproducibility.
2. **Checksum policy is strict by default.** Default mode and `--ref vX.Y.Z`
   MUST fail if the release has no `checksums.txt`. `--sha256` always wins
   when given. `--ref <branch|sha>` is an explicit moving target and skips
   verification with a loud warning.
3. **Interactivity survives the pipe.** `curl | bash` replaces stdin with the
   pipe, which would disable `init-project.sh`'s TTY-gated chooser
   (`[ -t 0 ]`). The bootstrap re-attaches the delegate's stdin to
   `/dev/tty`, so flagless users are still prompted one by one
   (tier → provider → engine → name → dest). PowerShell's console stdin
   survives `Invoke-Expression`, and `init-project.ps1` already prompts for
   missing mandatory parameters — no new prompt code on either side.
4. **Semver, including tool majors.** MAJOR = breaking change to generated
   project structure/behavior **or** adopting a tofu/terraform/terragrunt
   major whose changes break generated configs. MINOR = additive capability
   (new tokens, new flags, pin bumps that keep generated projects valid).
   PATCH = fixes with no intentional generated-output change. Trunk-based
   flow is unchanged: tags are cut directly on `main`, no release branches
   (`docs/release-process.md`).
5. **Scope guard — catalog only.** No template folder, no
   `docs/conventions.md`, no init-script change; `tests/gen-manifests.sh`
   must produce zero diff. New docs (`adr/`, `release-process.md`) are
   catalog-only and are NOT copied into generated projects, preserving house
   rule 5 (self-contained projects). Because no `conventions.md` change is
   involved, house rule 1's all-tiers-same-commit rule does not trigger —
   this paragraph is that justification.
6. **The entry point is gated like everything else.** `tests/run-all.{sh,ps1}`
   gain a T0-level bootstrap gate: instantiating through the bootstrap (local
   tarball source and local directory source) must produce trees identical to
   a direct init, and a corrupted tarball must be rejected on sha256
   mismatch. This enforces decision "no template logic" mechanically.

## Alternatives considered

Criteria used: C1 steps-to-template, C2 prerequisite footprint, C3
Windows/POSIX parity, C4 init-contract reuse (vs. forking), C5 version
pinning, C6 maintenance cost, C7 trust posture, C8 update story for generated
projects (weak requirement by design — generated projects are self-contained
per house rule 5, so a strong update path is a non-goal).

| Alternative | Verdict | Primary failing criterion |
|---|---|---|
| `dotnet new -i` scaffolding pack | Rejected | C2 + C4: needs the .NET SDK on an IaC user's machine; `dotnet new` has no native equivalent of the per-tier providers/ merge or tier-03 marker injection, so the logic would be forked into C# post-actions |
| cookiecutter / copier / yeoman as the generator | Rejected | C4: same fork problem — substitution is the easy 20%, the structural merge is the tested 80%; copier's update story additionally requires a live link back to the catalog, contradicting house rule 5 |
| GitHub "Use this template" / `gh repo create --template` | Rejected | C1: forks the whole catalog with zero substitution or merge; the user still ends up running an init script over it |
| `npm create` thin wrapper (create-vite model, catalog vendored at publish) | Deferred (sanctioned follow-up) | C2: requires Node, which an IaC user on Windows may not have — but registry trust and offline-after-install make it the right complement once the bootstrap proves out |
| brew tap / scoop bucket | Deferred | C6: a second packaging channel wrapping the same bootstrap; add on demand |
| static Go/Rust binary + goreleaser | Deferred | C6: best C2/C3 on paper, but a new toolchain and release pipeline to maintain while the shell scripts remain the contract |
| devcontainer / codespace template | Rejected | wrong direction: ships an environment, not project files |

## Consequences

- The bootstrap must stay thin; the parity gate (Decision 6) turns any
  future logic leak into a red T0 line.
- Catalog docs gain `docs/adr/` and `docs/release-process.md`; both are
  catalog-only (Decision 5).
- The first tag is a hard prerequisite: until a release is published, the
  default mode has nothing to resolve. The README carries an interim
  `--ref main` note that is removed at `v0.1.0`.
- Trust posture: the one-liner is pipe-to-shell. Mitigations are the pinned
  release + `checksums.txt` verification, a fully pinned documented form,
  and keeping clone-then-run as the documented fallback for environments
  that forbid piping. Documented asymmetry: inside PowerShell, `curl` is an
  alias for `Invoke-WebRequest`, so the `curl | bash` line is restricted to
  POSIX shells in all docs.
- The tarball the bootstrap downloads excludes nothing the init script
  needs; the parity gate's own tarball build documents the excludes list
  (`.git`, `tests/scratch`, `playground/projects`) and fails loudly if the
  entry point drifts from direct init.

## Deferred

- `npm create` vendored wrapper (the create-vite model) — sanctioned
  follow-up, same delegate core, additive.
- brew/scoop channel; static binary — revisit on demand.
- Remote path in CI — deliberately not in the test matrix (it needs a
  published release and network); exercised by the manual smoke test in
  `docs/release-process.md` at each release.
