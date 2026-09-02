# Tier 02 - Small Team

IaC starter for a **team of 2-8 people**: one root module per environment
(`envs/dev`, `envs/staging`, `envs/prod`), shared modules under `modules/`,
one isolated state per env (directories, not workspaces), pre-commit
guardrails, and a Taskfile so every command works the same with either engine
(`IAC_ENGINE=tofu` by default, `IAC_ENGINE=terraform` if you prefer).

## Who this is for

- 2-8 engineers touching the same IaC repo
- You want dev/staging/prod with **isolated state** - each env is its own
  directory with its own backend key and lock
- You want shared, reusable modules instead of copy-paste between envs
- You want review discipline (PR template, CODEOWNERS, pre-commit) and to be
  CI-ready later

## Layout

```text
.
├── Taskfile.yml                     # every engine command goes through a task
├── envs/
│   ├── dev/                         # root module + dev.tfvars (own state)
│   ├── staging/                     # root module + staging.tfvars (own state)
│   └── prod/                        # root module + prod.tfvars (own state)
├── modules/
│   └── baseline/                    # shared convention module - copy this shape
├── bootstrap/
│   ├── aws.md                       # create the shared state backend (once)
│   ├── azure.md
│   └── gcp.md
├── .github/PULL_REQUEST_TEMPLATE.md # plan-review checklist for PRs
├── CODEOWNERS.example               # rename once the repo is hosted
└── AGENTS.md                        # repo guide for humans and coding agents
```

After project init, each `envs/<env>/` also contains the merged `backend.tf`,
`provider.tf` and `starter.tf` for your chosen cloud (the raw provider layer
was merged in and removed; the env-name placeholder was replaced with the
directory name).

## Quickstart

```bash
# 1. Once per project: create the shared state backend.
#    Follow bootstrap/aws.md (or azure.md / gcp.md), then put the resulting
#    values into every envs/*/backend.tf.

# 2. Once per machine:
task engine-check                    # verifies an engine is on PATH
pip install pre-commit && pre-commit install

# 3. Set your project slug in each envs/*/*.tfvars (sample: "my-app").

# 4. Per env - dev first, then staging, then prod:
task init-backend ENV=dev            # real init against the remote state
task plan ENV=dev                    # writes envs/dev/tfplan - REVIEW IT
task apply ENV=dev                   # applies exactly the reviewed plan
git add -A && git commit -m "infra: dev baseline"  # lockfile is committed too
```

Repeat step 4 with `ENV=staging` and `ENV=prod`. All env-scoped tasks take
`ENV=` (default `dev`).

## Testing without a cloud

- **`task check ENV=dev`** - format check + backend-less init + validate.
  No credentials, no cloud calls.
- **`task plan-dry ENV=dev`** - plan with `-refresh=false` and `dry_run=true`:
  the provider skips credential and account validation, so no cloud APIs are
  called (the state backend itself must be reachable). Fake provider creds
  are enough, e.g. for AWS:

  ```bash
  AWS_ACCESS_KEY_ID=fake AWS_SECRET_ACCESS_KEY=fake task plan-dry ENV=dev
  ```

- **`task test`** - runs the `modules/baseline` tests with OpenTofu (fully
  offline; the module uses no providers). Terraform users: rely on
  `task check` and `task plan`.

## Pre-commit (team guardrails)

```bash
pip install pre-commit
pre-commit install        # once per clone
pre-commit run -a         # first full run; downloads tools
```

Hooks: `terraform_fmt`, `terraform_validate`, `terraform_tflint` and
`terraform_docs` (module READMEs are regenerated between their
`BEGIN/END_TF_DOCS` markers - never hand-edit between the markers).
**Windows:** the hooks need a POSIX shell - run them from Git Bash or WSL.

## Team workflow

1. Branch, change modules/envs, run `task check ENV=<env>`.
2. Open a PR - the template asks for the plan summary, lockfile status, tags
   and module docs.
3. Rename `CODEOWNERS.example` to `CODEOWNERS` once the repo is hosted; assign
   owners per area (prod: two reviewers).
4. Merge, then a teammate runs `task plan` / `task apply` per affected env -
   or wire `task check` into CI later.

## Growing out of this tier

- New env: copy `envs/dev`, set the env local, add a tfvars file, and put the
  env name into the new `backend.tf` state key (see AGENTS.md).
- New module: copy `modules/baseline` - markers, tests and all.
- Team bigger than ~8 people, cross-env composition or pipelines needed?
  Follow `docs/migrations/02-to-03.md`.
