# AGENTS.md - working in this repo

Ground rules for coding agents AND humans. Every engine command goes through a
task (`task <name>`); never invoke an engine binary directly - the Taskfile
picks the right one (`IAC_ENGINE=tofu` by default, falls back to `terraform`).

## Project map

- `envs/dev/`, `envs/staging/`, `envs/prod/` - one root module per environment.
  Each owns its tfvars, its backend key and its lock: state is NEVER shared.
- `envs/<env>/backend.tf`, `provider.tf`, `starter.tf` - merged at project init
  from the (now deleted) raw `providers/<cloud>/` layer; the env-name
  placeholder was replaced with the directory name. ALL cloud-specific config
  lives in these three files.
- `envs/<env>/main.tf`, `variables.tf`, `outputs.tf` - cloud-neutral wiring:
  `locals.env`, `common_tags`, and the `module "baseline"` call.
- `modules/baseline/` - shared convention module (name prefix + tags). The
  reference shape for every new module: README terraform-docs markers,
  `tests/`, no providers.
- `bootstrap/` - one-pagers that created the shared state backend.
- `.github/PULL_REQUEST_TEMPLATE.md`, `CODEOWNERS.example` - review guardrails.
- `Taskfile.yml` - the only entry point for commands.

## Running things

Env-scoped tasks take `ENV=dev|staging|prod` (default `dev`) and run inside
`envs/<ENV>/`. Examples: `ENV=staging task plan`,
`IAC_ENGINE=terraform task check ENV=prod`.

| Command | What it does |
| --- | --- |
| `task engine-check` | fail fast if no engine is on PATH |
| `task fmt` / `task fmt-check` | format / verify formatting, repo-wide |
| `task lint` | fmt-check + `tflint --recursive` |
| `task init` | backend-less init for one env |
| `task init-backend ENV=staging` | real init against remote state |
| `task validate` | validate one env |
| `task check ENV=dev` | fmt-check + init + validate - run before declaring done |
| `task plan ENV=dev` | write `envs/dev/tfplan` for review |
| `task plan-dry ENV=dev` | offline plan (no refresh, fake creds OK) |
| `task apply ENV=dev` | apply the reviewed tfplan only |
| `task destroy ENV=dev` | destroy an env |
| `task test` | module tests via OpenTofu (skipped for terraform) |

## Safety rules

1. **Bootstrap first.** Never run `task init-backend` before
   `bootstrap/<cloud>.md` ran and the values are in every `envs/*/backend.tf`.
2. **Prod is sacred.** NEVER apply to prod without a reviewed tfplan:
   `task plan ENV=prod`, human review, then `task apply ENV=prod`.
3. **Prod changes need 2 reviewers** per `CODEOWNERS` (rename
   `CODEOWNERS.example` once the repo is hosted).
4. **Never commit** state files, plan files or `.env` (all gitignored). The
   lockfile `.terraform.lock.hcl` IS committed - include it in PRs.
5. Run `task check ENV=<env>` for every env you touched before declaring done.

## How to grow

- **New module**: copy `modules/baseline/` wholesale - keep the
  `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` markers (pre-commit
  regenerates the docs between them), keep/add `tests/*.tftest.hcl`, stay
  provider-free unless the module must manage cloud resources.
- **New resource**: prefer a module over the env root; instantiate it in
  `envs/<env>/main.tf`. Replace the example resource in `starter.tf` once real
  resources exist.
- **New env**: copy `envs/dev` to `envs/<new>/`, set `locals.env = "<new>"`,
  rename the tfvars to `<new>.tfvars`, and edit `envs/<new>/backend.tf` so its
  state key contains `<new>` - after init the key is a literal per-env string;
  forgetting this makes the new env silently share dev's state.
- **Graduate**: team larger than ~8 people, cross-env composition or pipeline
  needs - follow `docs/migrations/02-to-03.md`.

## Pointers

- `README.md` - quickstart, testing without a cloud, pre-commit setup
- `bootstrap/` - backend creation per cloud
- `docs/conventions.md` - naming/tagging conventions (copied in at init)
- `docs/engine-duality.md` - how the tofu/terraform duality works (copied in
  at init)
