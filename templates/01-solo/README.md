# Solo IaC project (tier 01)

Plain Terraform/OpenTofu for one person running 1-2 environments (dev/prod)
from a single root module. Engine-swappable: set `IAC_ENGINE=tofu` or
`IAC_ENGINE=terraform` — the code uses nothing beyond Terraform >= 1.11.0 /
OpenTofu parity.

## Layout

```text
.
├── backend.tf        # remote state (merged in from providers/<cloud>/)
├── provider.tf       # cloud provider config (merged; exactly one cloud)
├── starter.tf        # example resource (merged; replace me)
├── dry_run.tf        # AWS-only offline-plan switch (merged; azure/gcp omit it)
├── versions.tf       # engine constraint only
├── main.tf           # naming/tag conventions + terraform_data placeholder
├── variables.tf      # project / environment
├── outputs.tf        # conventions + starter_instructions
├── dev.tfvars        # dev environment values
├── prod.tfvars       # prod environment values
├── bootstrap/        # run-once state-backend setup notes per cloud
├── tests/            # native tofu tests (no cloud needed)
├── Taskfile.yml      # task runner for everything below
├── .tflint.hcl
├── .pre-commit-config.yaml
└── .env.example      # credential variable names (values stay empty)
```

## Quickstart

1. Pick your cloud and follow `bootstrap/<cloud>.md` once to create the state backend; substitute the printed names into `backend.tf` and set your region in `provider.tf`.
2. `task engine-check` — verify `tofu` (or `terraform`) resolves.
3. `task init-backend` — initialize against the remote state.
4. `task plan ENV=dev` — review the plan it prints.
5. `task apply` — apply the reviewed `tfplan`.
6. Commit — including `.terraform.lock.hcl` (pinning is the point).

## Testing without a cloud

```sh
task check      # fmt-check + offline init (-backend=false) + validate - zero cloud calls

# AWS offline plan with fake credentials (dry_run flips the provider skip flags):
export AWS_ACCESS_KEY_ID=fake
export AWS_SECRET_ACCESS_KEY=fake
export AWS_REGION=us-east-1
task plan-dry

task test       # native suite in tests/ via `tofu test`; no credentials needed
```

## Windows

The repo itself is Windows-safe. The pre-commit hooks (`.pre-commit-config.yaml`)
need a POSIX shell — run `pre-commit` from Git Bash or WSL. Taskfile commands go
through go-task's bundled shell and work in any terminal.

## Growing out of this tier

A second person on the project, modules, CI, or per-environment stacks — see
`docs/migrations/01-to-02.md` (copied in at init).
