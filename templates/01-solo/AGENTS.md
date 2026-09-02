# AGENTS.md

Guidance for AI coding agents (and humans) working IN this generated project.
Tier: 01-solo — plain Terraform/OpenTofu, one person, 1-2 environments, a
single root module. Engine-swap-compatible: nothing here goes beyond what
Terraform >= 1.6 and OpenTofu both support.

## Project map

| Path | What it is |
| ---- | ---------- |
| `versions.tf` | Engine version constraint only (>= 1.6, < 2.0). |
| `main.tf` | Naming/tagging `locals` + the `terraform_data.conventions` placeholder to replace with real resources. |
| `variables.tf` | `project` (required, kebab-case, no default), `environment` (default `dev`), `dry_run` (AWS offline-plan switch). |
| `outputs.tf` | `conventions` (rendered name prefix) and `starter_instructions`. |
| `backend.tf` | Merged in at instantiation from `providers/<cloud>/backend.tf`. Remote state config. |
| `provider.tf` | Merged in from `providers/<cloud>/provider.tf`. Cloud provider + auth mode. Exactly one cloud exists here. |
| `starter.tf` | Merged in from `providers/<cloud>/starter.tf`. Example resource; delete once real resources exist. |
| `dev.tfvars` / `prod.tfvars` | Per-environment values (`project`, `environment`). |
| `bootstrap/` | Run-once CLI notes for how the state backend was created (aws/azure/gcp). |
| `tests/outputs.tftest.hcl` | Native `tofu test` suite; needs no cloud credentials. |
| `Taskfile.yml` | All commands below; resolves the engine binary (`tofu` preferred, `terraform` fallback). |
| `.tflint.hcl`, `.pre-commit-config.yaml` | Lint config and hooks (pre-commit needs a POSIX shell on Windows). |
| `.env.example` | Credential env-var names per cloud; values stay empty. |

## Running things

- Engine: defaults to `tofu`; override with `IAC_ENGINE=terraform`.
- Environment: defaults to `dev`; override with `ENV=prod` (must match a `<env>.tfvars` file).

| Command | What it does |
| ------- | ------------ |
| `task engine-check` | Print the resolved engine binary; fail if neither is installed. |
| `task check` | No-cloud self-check: fmt-check, offline init (`-backend=false`), validate. |
| `task plan ENV=dev` | Real plan against the cloud; writes `tfplan`. |
| `task plan-dry` | Offline plan: `-refresh=false` + `dry_run=true` (AWS skip flags) with fake credentials. |
| `task apply` | Apply the previously reviewed `tfplan`. |
| `task destroy ENV=dev` | Destroy the selected environment. |
| `task test` | Run `tests/` via `tofu test`; prints a skip reason under plain terraform. |
| `task fmt` / `task fmt-check` / `task lint` | Format, format-check, lint (tflint optional). |

## Safety rules

1. Bootstrap-first: the remote backend in `backend.tf` must already exist (see `bootstrap/`) before `task init-backend`. Never casually delete or recreate the state bucket/container — live state lives there.
2. Never `apply` without a reviewed `tfplan`; never hand-edit `*.tfstate`.
3. Never commit state files or `.env`. The lockfile `.terraform.lock.hcl` IS committed.
4. Run `task check` before declaring any work done.
5. Keep code engine-neutral (no engine-specific syntax) so `IAC_ENGINE=terraform` keeps working.

## How to grow

- Add real resources to `main.tf` (patterns in `starter.tf`; delete it once superseded).
- A second or third environment is just another `<env>.tfvars` file plus `task plan ENV=<env>`.
- Need modules, multiple stacks, CI, or a teammate? Graduate to tier 02: `docs/migrations/01-to-02.md`.

## Pointers

- `README.md` — human-facing quickstart.
- `bootstrap/` — how the state backend was provisioned.
- `docs/conventions.md` — repo-wide naming/tagging conventions (copied in at init).
- `docs/engine-duality.md` — Terraform/OpenTofu compatibility rules (copied in at init).
