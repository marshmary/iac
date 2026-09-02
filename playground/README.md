# Playground — disposable real-project testing for all four tiers

A throwaway workspace that instantiates all four tiers and runs them against
**local emulators** (LocalStack for AWS, Azurite for Azure) so you can exercise
real `init → plan → apply → destroy` cycles with zero cloud account.

Everything here is self-contained: runtime artifacts (state, plan files,
`.terraform` caches, `.env`) live only under `playground/projects/`, which is
gitignored. Nothing under `templates/`, `scripts/` or `tests/` is modified.

## Layout

```
playground/
├── compose.yml            # the single compose file: localstack + azurite
├── up.sh                  # instantiate 4 tiers + boot emulators + localize + bootstrap AWS state
├── down.sh                # compose down -v (emulators + volumes)
├── localize.sh            # inject LocalStack endpoint + path-style S3 into generated projects
├── state-bootstrap/main.tf # provider-free module that creates the S3 bucket + lock table
├── projects/              # generated tier projects (gitignored, disposable)
└── logs/                  # up.sh smoke log (gitignored)
```

## Quickstart

```sh
playground/up.sh            # needs docker/podman + tofu (or terraform)
# ...read the printed cheat-sheet, then per tier:
#   Tier 01:  cd playground/projects/01-solo && \
#             AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 \
#             task init-backend && task plan ENV=dev && task apply && task destroy ENV=dev
#   Tier 02:  cd playground/projects/02-small-team && ... task init-backend ENV=dev && task plan ENV=dev && task apply ENV=dev
#   Tier 03:  cd playground/projects/03-team-terragrunt && ... task init-backend ENV=dev && task plan ENV=dev && task apply ENV=dev
#   Tier 04:  cd playground/projects/04-large-terragrunt && ... task hcl-validate PLATFORM=aws ENV=dev COMPONENT=baseline
playground/down.sh          # stop + remove emulators (projects/ left for inspection)
```

## What each tier actually proves

| Tier | Emulator used | Real apply coverage |
|------|---------------|---------------------|
| 01 | LocalStack | `aws_s3_bucket` starter + S3/DynamoDB backend |
| 02 | LocalStack | `aws_s3_bucket` starter (per env) + backend |
| 03 | LocalStack (backend only) | `baseline` component is `terraform_data` (provider-free), applies offline; remote state via LocalStack |
| 04 | LocalStack (backend only) | `baseline` component provider-free; registry modules (`git::`) are placeholders until replaced |

GCP has no free emulator (use offline `validate`/`dry-run`). Azurite emulates
Azure storage only (enough for the `azurerm` backend, not resource groups).

## Two LocalStack gotchas (already handled for you)

1. **Community image**: plain `localstack/localstack:latest` now pulls the Pro
   edition, which exits with "License activation failed" without a
   `LOCALSTACK_AUTH_TOKEN`. `compose.yml` pins `localstack/localstack:4` (OSS).
2. **Path-style S3**: LocalStack serves one edge endpoint, so virtual-hosted
   bucket URLs (`bucket.localhost`) don't route. `localize.sh` injects
   `endpoint` + `use_path_style` + `skip_*` into the generated S3 backends and
   `s3_use_path_style` into the AWS providers, so real applies work. The state
   backend bootstrap is idempotent (imports any pre-existing bucket/table from
   the persistent LocalStack volume before applying).

## Offline-only usage (no Docker, no emulators)

```sh
playground/up.sh --skip-emulators   # just instantiate the four tiers
# run each tier's `task check` (fmt-check + backend-less init + validate)
```

## Teardown / cleanup

`down.sh` removes containers and volumes. `projects/` and `logs/` are left for
inspection; delete them (`rm -rf playground/projects playground/logs`) to start
fresh — `up.sh` already wipes the four tier subfolders on each run.
