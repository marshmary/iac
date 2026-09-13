# Enhancement plan

> Working document created 2026-09-12 from a full-repo scan (templates, scripts,
> tests, playground, docs). Every "verified" finding below was checked directly
> against the code before being listed. **Status: all phases executed 2026-09-13**
> (see the table and the phase commits). As promised, the behavioral outcomes
> have been folded into the real contract docs (`docs/conventions.md`,
> `docs/testing.md`, `docs/placeholders.md`, AGENTS.md); this file is now
> historical — keep only the open item (LICENSE) on your radar.

## Status overview

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Verified defects | **Done** |
| 2 | Cross-tier drift sweep | **Done** |
| 3a | Verification capabilities: pin test, rego tests, dotenv, ps1 parity | **Done** |
| 3b | Pipeline capabilities: CI skeletons, drift task, security scanning | **Done** |
| 3c | UX & first-run: tier 04 bootstrap, interactive chooser, playground pass | **Done** |
| 4 | Polish: line endings, README prune, Renovate, LICENSE decision | **Done** (LICENSE: deferred — owner decision) |

Legend: Pending → In progress → **Done (`<commit>`)** or Skipped (reason).
Executing agents update their own phase status in this file as the last step
before committing. Phases run sequentially (shared working tree, trunk-based).

## Phase 1 — Verified defects (fix first; all cheap)

1. **Tier 04 naming policy is a silent no-op on AWS S3.**
   `templates/04-large-terragrunt/policy/naming.rego:35` maps
   `aws_s3_bucket` → attribute `"name"`; the attribute is `bucket`, so both
   naming rules skip every S3 bucket. Fix the key map and add coverage while
   here (a test lands in Phase 3a #5).
2. **T6 emulator compose pins a known-broken tag.**
   `tests/docker-compose.emulators.yml:13` uses `localstack/localstack:latest`
   — the exact tag `playground/compose.yml` documents as pulling the Pro
   edition and dying without a token. Pin `:4` like the playground; pin
   azurite to a stable tag too.
3. **Engine-duality violation in a runbook.**
   `templates/04-large-terragrunt/runbooks/state-incident.md:36,72` hardcode
   `--tf-path tofu`. Rewrite engine-neutral (resolve via the Taskfile /
   `IAC_ENGINE`), per the tier's own AGENTS.md rule.
4. **The `.env` written by init is inert + a false claim.**
   No tier Taskfile has `dotenv:`, so the recorded `IAC_ENGINE` never takes
   effect (making it load everywhere is Phase 3a #7). Phase 1 scope: fix
   tier 02's `.env.example` claim "The Taskfile auto-loads .env" to state the
   truth, matching tier 01's wording.
5. **Tier 04 GCP tags clobber their own source of truth.**
   `platforms/gcp/root.hcl` merges `Project = <project-id>` over the
   mandatory `Project` from `common/tags.hcl` (merge is later-wins). Keep the
   mandatory tag authoritative (separate key or merge order) and document the
   GCP-labels-must-be-lowercase caveat where labels are consumed.
6. **`run-all.ps1` claims coverage it doesn't have.**
   Header says T1 fmt-check; it implements none (T0 + single-engine T2 only)
   and `Compare-Object` is case-insensitive by default. Also `run-all.sh`
   tier-04 terragrunt loop runs the same whole-tree check 3× instead of
   per-platform. Fix the loop now; full ps1 parity is Phase 3a #10 — here
   only correct the false header/docs claims (`docs/testing.md` included) and
   the case-sensitivity.
7. **Init-script parity gaps (ps1):** `-Provider all` on tiers 01–03 dies
   with a raw path error instead of sh's friendly validation; a failed
   `git init` is silently ignored; no binary-file skip during substitution
   (rewrite-only-if-changed makes corruption unlikely — add a cheap
   NUL-byte/binary guard or document the accepted difference).
8. **Stale docs:** tier 01 `AGENTS.md`/`README.md` say `>= 1.6` vs actual
   `>= 1.11.0`; tier 01 `providers/aws/provider.tf` points at `variables.tf`
   for `dry_run` (it lives in `dry_run.tf`); tier 01 `AGENTS.md` says
   `dry_run` is in `variables.tf`; tier 04 `platforms/aws/README.md` claims
   bootstrap creates a lock table while `bootstrap.md` correctly says
   S3-native locking needs none; `platforms/aws/bootstrap.md` runs
   `aws login` (not a v2 command — `aws sso login` / `aws configure`);
   `docs/conventions.md:33` typo "workbooks" → "workspaces".

## Phase 2 — Cross-tier drift (one conventions-aligned sweep)

The house rule is "same commit, all four tiers". Each item hurts the
`docs/migrations/` path because migrating silently changes behavior:

- **Tag vocabulary:** tiers 01/02 use `Env` + `ManagedBy = "iac"`; tiers 03/04
  use `Environment` + `ManagedBy = "terragrunt"`. `conventions.md` is the
  contract and says `Env` / `ManagedBy=iac` — align tiers 03/04 to the doc
  (root.hcl locals, `common/tags.hcl`, module code + any tests asserting the
  old keys, and prose that mentions them).
- **Project-slug validation:** tier 01 `1–63` chars, tier 02 `3–32`, tier 03
  unbounded — a slug valid at tier 01 can be rejected after migrating to
  tier 02. Unify on the documented kebab-case 1–63 rule (cloud name limits).
- **GCP env var:** `GOOGLE_CLOUD_PROJECT` (01/04) vs `GOOGLE_PROJECT`
  (02/03); tier 02 also omits `AWS_REGION`. Align on whatever the provider
  `env` blocks actually reference and make `.env.example` sets consistent.
- **Bootstrap hardening:** same cloud, different hardening per tier (tier 02
  AWS: no encryption; tier 02 Azure: no min-TLS/no public-access false).
  Align every tier's `bootstrap/<cloud>.md` to the strongest variant
  (AWS: versioning + SSE + public-access-block; Azure: min-TLS 1.2 +
  `--allow-blob-public-access false`; GCP: UBLA + full API list + IAM note).
- **pre-commit drift:** tier 03's hook is `hcl fmt --check` (check-only),
  tier 04's mutates in pre-commit — unify on check-only + a separate fix
  task. `terraform_docs` args differ between 02/03 — unify on tier 02's
  inject args. Tier 02's fmt hook should exclude `^providers/` like tier 03
  (raw provider layers churn pre-init).
- **Taskfile nits:** tier 03 `task test` guards on `IAC_ENGINE` instead of
  the resolved `IAC_BIN` (runs `terraform test` when tofu is absent);
  `plan-dry` (tiers 01/02) passes `-var dry_run=true` on azure/gcp projects
  where the variable doesn't exist — guard with a `dry_run.tf`-exists
  precondition and an honest skip message.
- **Unpinned policy tooling:** conftest/OPA version guidance nowhere; tflint
  unpinned in every tier. Document pins where the Docker runner pins them
  and note tflint's plugin-pin limitation in `docs/testing.md`.

## Phase 3 — New capabilities (split 3a/3b/3c for execution)

Ranked by value ÷ effort as originally proposed:

### 3a — Verification capabilities

- **#2 Pin-consistency test (new T0-level check, zero CLIs).** Engine pins
  must move atomically across `.terraform-version`, `.opentofu-version`,
  `.terragrunt-version` (tiers 03/04), the Dockerfile runner ARGs, and
  `docs/engine-duality.md`. Ship a standalone check wired into
  `run-all.{sh,ps1}` + a `docs/testing.md` row.
- **#5 Rego policy unit tests.** `policy/tests/*_test.rego` with inline mock
  plan resources (including the S3 `bucket` case from Phase 1), run via
  `conftest verify` — wired into tier 04's Taskfile and `run-all.sh`.
- **#7 Make `.env` real.** Add `dotenv: ['.env']` to every tier Taskfile so
  the init-recorded `IAC_ENGINE` actually loads; align all `.env.example`
  wording; note the behavior in `conventions.md` (Engine section).
- **#10 run-all.ps1 honest parity.** Implement T0–T2 for real
  (case-sensitive manifest compare, per-engine fmt-check, `task --list`,
  dual-engine loop where CLIs exist), and state plainly in the header +
  `docs/testing.md` that T3+ remain `run-in-docker.sh` territory. PS 5.1
  syntax only (no `??`, no ternary).

### 3b — Pipeline capabilities

- **#1 Opt-in CI skeletons.** `--ci <github|gitlab|none>` init flag (default
  `none`, preserving the local-first philosophy). GitHub flavor: per-tier
  workflow running the offline checks the project already ships (`task
  check` / engine install → fmt/init/validate; `tofu test` where tests
  exist; tier 04 adds `conftest verify` + policy gate). GitLab flavor:
  minimal `.gitlab-ci.yml` equivalent. Workflows are deleted unless
  `--ci` is passed; README "future extensions" wording updated; both init
  scripts + `docs/placeholders.md`-adjacent docs + golden manifests
  regenerated for the default path.
- **#3 Drift detection as a task.** `task drift` in tiers 02–04:
  `plan -detailed-exitcode`, report exit 2 as drift (TG tiers via terragrunt
  with `--tf-path`). Plus a scheduled weekly workflow in the CI skeletons
  (tiers 03/04) — the drift runbook already prescribes this cadence.
- **#4 Security scanning tier.** Checkov: per-tier `.checkov.yaml`,
  pre-commit hook, `run-all.sh` level (skip-if-absent like tflint), pinned
  ARG in the Docker runner, `docs/testing.md` row.

### 3c — UX & first-run

- **#6 Tier 04 first-run experience.** Every `source` points at
  `github.com/__PROJECT_NAME__/iac-modules?ref=v0.0.0` — nonexistent — so
  `task plan` fails out of the box. Ship a `modules-local/baseline` fallback
  (mirroring tier 03's module) as the default source with the registry form
  kept as a commented alternative + README guidance. Split
  `__AWS_ACCOUNT_ID__`/`__AZURE_SUBSCRIPTION_ID__` into per-env tokens
  (`_DEV`/`_PROD`) in `common/accounts.hcl` so dev/prod can differ —
  update `docs/placeholders.md`, both init scripts, and any sweep.
- **#8 Interactive tier chooser.** `init-project.{sh,ps1}` with missing
  required flags and a TTY prompt interactively (tier → provider → engine →
  name → dest). Non-interactive flag-driven behavior (what tests use) must
  be byte-identical to today.
- **#9 Playground honesty pass.** Make `localize.sh` idempotent (guard
  against double-injection on re-`up.sh`). Azurite runs in compose but
  nothing localizes azure projects to it — either clearly mark it as
  future-work in `compose.yml` + `playground/README.md` or wire it; do not
  leave it looking wired when it isn't.

## Phase 4 — Polish

- `.gitattributes` forces `*.ps1 eol=crlf` while `.editorconfig` mandates LF
  everywhere — editors and git rewrite each other. House rule 4 says LF;
  align both to LF and renormalize.
- README "future extensions" list: prune entries absorbed by 3b/3c, keep
  genuinely-out-of-scope ones (infracost stays deferred unless requested).
- Renovate config for the catalog's own pins (Dockerfile ARGs, version
  files) with minimal custom managers.
- **LICENSE: deferred — owner decision.** A license choice for generated
  projects is not something an agent should pick; recorded here so it stops
  being invisible.

## Sequencing notes

Phase 1 as individually-verifiable fixes (each confirmed via
`tests/run-in-docker.sh`), pin-consistency (3a #2) lands early to guard later
work, Phase 2 is one mirrored sweep per house rules, 3b items 1+3+5 reinforce
each other, everything else independent. Verification protocol per commit is
the one in `AGENTS.md`: `bash -n`, PowerShell parse check, `gen-manifests`
diff review, `run-in-docker.sh`, structural sweep.
