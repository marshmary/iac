# AGENTS.md

Machine-facing guide for agents (AI or human) working in this repository.
Human-oriented introduction and quickstart: `README.md`.

## Project map

- `root.hcl` — shared Terragrunt config: project/env locals, common tags,
  and the auto-injected cloud block between the `CLOUD PROVIDER` markers
  (backend + provider `generate` blocks, written by `scripts/init-project`
  from `providers/<cloud>/root-provider.hcl`, which is then deleted). Edit
  the locals freely; treat the injected block as generated-but-reviewable.
- `envs/<env>/env.hcl` — per-environment locals (environment name, tier).
- `envs/<env>/<component>/terragrunt.hcl` — one unit per component per
  environment: includes `root.hcl` (with `expose = true`), points
  `terraform.source` at `modules/<component>`, maps shared locals into
  module inputs.
- `modules/<name>/` — reusable, provider-free Terraform/OpenTofu modules
  with `examples/` and `tests/` (`*.tftest.hcl`).
- `bootstrap/<cloud>.md` — one-pager to create the shared state backend
  before the first apply.

## Running things

All commands go through the Taskfile. The engine binary (tofu or
terraform) and terragrunt are resolved automatically — never call them
directly with hardcoded names.

| Command | What it does |
| --- | --- |
| `task engine-check` | Verify an engine and terragrunt are installed |
| `task hclfmt` / `task hclfmt-check` | Format / check Terragrunt HCL |
| `task hcl-validate ENV=dev` | Parse-validate one unit (COMPONENT to retarget) |
| `task fmt` / `task fmt-check` | Format / check `modules/baseline` |
| `task init` / `task validate` | Module init (`-backend=false`) / validate, offline |
| `task check` | Offline suite: HCL fmt+validate and module fmt+init+validate |
| `task init-backend ENV=dev` | `terragrunt init` for one unit — wires remote state |
| `task plan ENV=dev` / `task apply ENV=dev` | Plan one component to `tfplan` / apply it |
| `task run-all-plan ENV=dev` / `task run-all-apply ENV=dev` | Whole-environment plan / apply |
| `task graph ENV=dev` | Dependency graph to `deps.dot` / `deps.png` |
| `task destroy ENV=dev COMPONENT=baseline` | Destroy one component (interactive) |
| `task test` | Module test suite (tofu engine only) |

Engine switch: prefix any command with `IAC_ENGINE=terraform`
(default `tofu`); the Taskfile falls back to whichever of the two is
installed and passes the choice to Terragrunt via `--tf-path`.

## Safety rules

- Bootstrap first: no `init-backend`/`plan`/`apply` before the state
  backend from `bootstrap/<cloud>.md` exists and its values are in the
  injected backend block of `root.hcl`.
- Apply only a plan you have read: `task apply` consumes the `tfplan`
  written by the preceding `task plan`.
- Never commit state files, plan files or `.env` (all gitignored — keep
  it that way; `.env.example` is the only committed variant).
- `run-all-apply` is the most dangerous command in this repo: always run
  `run-all-plan` first and read every unit's plan before applying.
- Run `task check` before declaring any work done.

## How to grow

- Add a component: create `envs/<env>/<name>/terragrunt.hcl` copied from
  the `baseline` unit (adjust `source` and inputs) plus
  `modules/<name>/` with README tf-docs markers and `tests/`. Wire it to
  other units with `dependency` blocks — see the reference comment in
  `envs/dev/baseline/terragrunt.hcl`.
- Add an environment: copy the `envs/dev/` subtree and edit its `env.hcl`.
- Graduate to tier 04 when this layout stops fitting: follow
  `docs/migrations/03-to-04.md`.

## Pointers

- `README.md` — orientation, quickstart, offline-testing notes.
- `bootstrap/` — cloud-specific state-backend one-pagers.
- `docs/conventions.md` and `docs/engine-duality.md` — copied in by the
  catalog's init script.
- `.terragrunt-version` / `.terraform-version` / `.opentofu-version` —
  version pins read by tgenv / tfenv / tenv.
