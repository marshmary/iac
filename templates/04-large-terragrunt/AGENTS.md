# AGENTS.md - operating manual for this repository

For humans and AI coding agents working in this tier-04 (large, multi-team)
live repository. Read this before running or changing anything.

## Project map

- `common/` - cross-cloud registries. THE single source of truth; components
  read from here and nothing duplicates these values anywhere else.
  - `common/accounts.hcl` - env to AWS-account / Azure-subscription /
    GCP-project map. Each `platforms/<cloud>/root.hcl` loads it via
    `read_terragrunt_config` and resolves the entry for its env.
  - `common/regions.hcl` - primary region per cloud.
  - `common/tags.hcl` - the mandatory tag set (`Project`, `ManagedBy`).
    `policy/tags.rego` enforces exactly this definition at plan time.
- `platforms/<aws|azure|gcp>/` - one subtree per cloud. Multi-cloud org: all
  three stay; do not strip platforms you are not using.
  - `root.hcl` - shared locals (env, account, region, tags) + generated
    backend and a commented provider block for the whole subtree.
  - `bootstrap.md` - one-pager to provision that cloud's state backend.
  - `envs/<env>/<component>/terragrunt.hcl` - the deploy unit. The component
    path itself is the state key: `<platform>/envs/<env>/<component>`.
- `policy/` - OPA/conftest rules that gate applies (see `policy/README.md`).
- `runbooks/` - procedures: drift, new environments, state incidents.

## Running things

Engine duality: this repo runs OpenTofu OR Terraform - never assume one.
Tasks resolve the binary at run time (`task engine-check` prints what was
found; `IAC_ENGINE=terraform` flips the preference). Do not write engine
names into scripts or docs; `docs/engine-duality.md` (copied in by init) is
the reference.

The task matrix - always pass the scope explicitly:

| Goal | Command |
| --- | --- |
| toolchain sanity | `task engine-check` |
| format / validate one component | `task hcl-validate PLATFORM=aws ENV=dev COMPONENT=baseline` |
| offline repo-wide check | `task check` (format gate + dev baseline of every platform) |
| plan one component | `task plan PLATFORM=azure ENV=dev COMPONENT=baseline` |
| policy gate the saved plan | `task policy-check PLATFORM=gcp ENV=dev COMPONENT=baseline` |
| apply the reviewed plan | `task apply PLATFORM=aws ENV=prod COMPONENT=baseline` |
| plan a whole scope | `task run-all-plan PLATFORM=aws ENV=dev` |
| apply a whole scope | `task run-all-apply PLATFORM=aws ENV=dev` (danger - below) |
| dependency graph | `task graph PLATFORM=azure ENV=dev` |

Danger notes:

- `run-all-apply` is the big red button: it fans out non-interactively across
  every component under the scope. ALWAYS run `run-all-plan` for the same
  scope, read it, and only then apply.
- `task apply` refuses to run without a saved `tfplan` - keep it that way.
  Policy-check before apply: `task plan` -> review -> `task policy-check` ->
  `task apply`.

## Safety rules

1. Bootstrap first per platform: follow `platforms/<cloud>/bootstrap.md`
   before the first plan on a platform. State backends are pre-provisioned,
   never managed in-tree.
2. Never apply without a reviewed plan AND a passing `task policy-check`.
3. Never edit state directly. Stuck lock, imports, corruption: go to
   `runbooks/state-incident.md` first - it starts with "snapshot the state".
4. Never commit state files, plans, or `.env` (`.gitignore` covers the known
   shapes; still review `git status` before committing).
5. Prod is explicit: pass `PLATFORM` and `ENV` on the command line for every
   prod operation, and `run-all-apply` in prod needs two humans per team
   convention - one operates, one reviews the plan output.
6. Run `task check` before declaring any change done.

## How to grow

- Add a component: create `platforms/<cloud>/envs/<env>/<component>/terragrunt.hcl`
  by copying `baseline/`, point `terraform.source` at a pinned registry ref,
  wire inputs from `include.root.locals.*`. Add dependencies between
  components with `dependency` blocks when order matters.
- Add an environment: follow `runbooks/adding-an-environment.md` (copy the
  `envs/` subtree per platform, extend `common/accounts.hcl`; state keys
  inherit the pattern automatically).
- Add a platform: copy the `platforms/aws` shape (root.hcl + README.md +
  bootstrap.md + envs/), add the registries entries in `common/` - three
  files plus registry keys, nothing else.

## Modules live in the registry repo

This tree contains NO module code. Every `terraform.source` points at the
module registry repository:

    git::https://github.com/__PROJECT_NAME__/iac-modules.git//baseline?ref=v0.0.0

(that URL is a PLACEHOLDER - replace it with your registry). Rules:

- always pin `?ref=vX.Y.Z` - a tag, never a branch;
- bump pins via PR so reviewers see module changes land;
- a local escape hatch exists (vendoring into `modules-local/` at the repo
  root) - documented in each component's header comment.

## Pointers

- `README.md` - orientation, quickstart, registry and policy conventions.
- `runbooks/` - `drift-remediation.md`, `adding-an-environment.md`,
  `state-incident.md`.
- `docs/conventions.md` and `docs/engine-duality.md` - copied in by init
  (placeholders until then).
