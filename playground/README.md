# Playground — disposable real-project testing for all four tiers

A throwaway workspace that instantiates every tier × cloud and runs them
against the **floci emulator trio** ([floci.io](https://floci.io), MIT) so you
can exercise real `init → plan → apply → destroy` cycles across **all three
clouds' APIs** with zero cloud account.

Everything here is self-contained: runtime artifacts (state, plan files,
`.terraform` caches, `.env`) live only under `playground/projects/`, which is
gitignored. Nothing under `templates/`, `scripts/` or `tests/` is modified.

## Layout

```
playground/
├── compose.yml                 # the floci trio: floci :4566, floci-az :4577, floci-gcp :4588
├── up.sh                       # instantiate 10 projects + boot emulators + localize + bootstrap 3 state planes
├── down.sh                     # compose down -v (emulators + volumes)
├── localize.sh                 # inject emulator endpoints into generated projects (per cloud)
├── state-bootstrap/
│   ├── main.tf                 # provider-free module that creates the AWS S3 state buckets
│   ├── az-container.sh         # curl + openssl SharedKey blob-container creator (floci-az)
│   └── fake-gcp-credentials.json # throwaway service-account key whose token_uri points at floci-gcp
├── projects/                   # generated tier x cloud projects (gitignored, disposable)
└── logs/                       # up.sh smoke log (gitignored)
```

## Quickstart

```sh
playground/up.sh            # needs docker/podman + tofu (or terraform)
# ...read the printed cheat-sheet. AWS full-apply example:
cd playground/projects/01-solo-aws && \
  AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 \
  task init-backend && task plan ENV=dev && task apply && task destroy ENV=dev
# GCP needs two env vars (the localized gcs backend is otherwise env-only):
export STORAGE_EMULATOR_HOST=http://localhost:4588
export GOOGLE_APPLICATION_CREDENTIALS=playground/state-bootstrap/fake-gcp-credentials.json
playground/down.sh          # stop + remove emulators (projects/ left for inspection)
```

## What each tier × cloud actually proves

| Tier | AWS (floci :4566) | Azure (floci-az :4577) | GCP (floci-gcp :4588) |
|------|-------------------|------------------------|-----------------------|
| 01 | full apply: `aws_s3_bucket` starter + S3 backend | state backend (blob) only; `task check` offline for the starter | state backend (GCS) only; `task check` offline for the starter |
| 02 | full apply per env: starter + backend | state backend per env | state backend per env |
| 03 | backend-backed `baseline` apply (`terraform_data`) | backend-backed `baseline` apply | backend-backed `baseline` apply |
| 04 | backend-backed `baseline` apply (AWS platform) | backend-backed `baseline` apply (Azure platform) | backend-backed `baseline` apply (GCP platform) |

**Honest limits, by design:** no free emulator implements the Azure ARM or
Google resource planes, so the `azurerm_resource_group` / `google_storage_bucket`
starters cannot apply locally — for those, `task check` (offline fmt +
backend-less init/validate) is the ceiling, same as T2 in `docs/testing.md`.
The state plane (every tier's backend) IS real on all three clouds: S3 on
floci, Azure Blob on floci-az (Azurite wire-compatible), GCS on floci-gcp.

## Gotchas (already handled for you)

1. **Pinned images**: `compose.yml` pins `floci/floci:2.2.0`,
   `floci/floci-az:0.14.0`, `floci/floci-gcp:0.10.0` — no `latest` drift
   (the same lesson the LocalStack Pro-tag incident taught us).
2. **Path-style S3**: floci serves one edge endpoint, so virtual-hosted bucket
   URLs (`bucket.localhost`) don't route. `localize.sh` injects `endpoint` +
   `use_path_style` + `skip_*` into the generated S3 backends and
   `s3_use_path_style` into the AWS providers (tiers 01/02).
3. **State locking is disabled on AWS locally**: the templates use S3-native
   `use_lockfile` locking, which needs S3 conditional writes (`If-None-Match`)
   — not (yet) documented for floci. `localize.sh` flips `use_lockfile` to
   `false` in the generated copies; a single-user playground loses nothing.
   If you need local locking, floci's own Terraform recipe uses a DynamoDB
   lock table (`dynamodb_endpoint` + `dynamodb_table`).
4. **GCP credentials are fake on purpose**: `fake-gcp-credentials.json` is a
   throwaway RSA key whose `token_uri` points at floci-gcp's unvalidated JWT
   exchange; combined with `STORAGE_EMULATOR_HOST` it lets the `gcs` backend
   authenticate and store state locally. It authenticates against nothing real.
5. **Azure containers are per-tier**: everything local shares the well-known
   `devstoreaccount1` account, so `localize.sh` rewrites `container_name` to
   `tfstate-01..04` to keep tiers' state from mixing. Containers are created
   by `state-bootstrap/az-container.sh` (SharedKey-signed `PUT`, no az CLI).

## Offline-only usage (no Docker, no emulators)

```sh
playground/up.sh --skip-emulators   # instantiate + localize the ten projects
# run each project's `task check` (fmt-check + backend-less init + validate)
```

## Teardown / cleanup

`down.sh` removes containers and volumes. `projects/` and `logs/` are left for
inspection; delete them (`rm -rf playground/projects playground/logs`) to start
fresh — `up.sh` already wipes the per-tier subfolders on each run.
