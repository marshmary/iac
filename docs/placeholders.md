# Placeholder tokens

Template files contain `__TOKEN__`-style placeholders. `init-project`
substitutes them at instantiation and then **fails if any survive**
(`grep -rEn '__[A-Z0-9_]+__' .` must be empty).

## Token reference

| Token | Used by | Default (from `-n <name>`) |
|-------|---------|---------------------------|
| `__PROJECT_NAME__` | everywhere | the `-n/--name` value |
| `__REGION__` | provider/backend files | aws `us-east-1`, azure `eastus`, gcp `us-central1` (override with `--region`) |
| `__STATE_BUCKET__` | aws s3 / gcp gcs backends | `<name>-tfstate` |
| `__DYNAMO_TABLE__` | aws state locking | `<name>-tflock` |
| `__STATE_RESOURCE_GROUP__` | azure backend | `<name>-tfstate-rg` |
| `__STATE_STORAGE_ACCOUNT__` | azure backend | first 17 alnum chars of `<name>` + `tfstate` (24-char limit) |
| `__STATE_CONTAINER__` | azure backend | `tfstate` |
| `__GCP_PROJECT__` | gcp provider | `<name>-project` — **always replace with your real project id** |
| `__ENV__` | tier 02 merged files | each env dir name (`dev`, `staging`, `prod`) |
| `__AWS_ACCOUNT_ID__` | tier 04 `common/accounts.hcl` | `000000000000` — replace with real account ids |
| `__AZURE_SUBSCRIPTION_ID__` | tier 04 `common/accounts.hcl` | all-zero GUID — replace with real subscription ids |

## Rules for template maintainers

1. Tokens appear ONLY in: backend files, provider files, starter resources,
   cloud-layer variable files, tfvars `project` values, Terragrunt `generate`
   contents, and Taskfile backend snippets.
2. Never pre-substitute a "sample" value — a half-substituted template passes
   the token sweep and ships broken.
3. Adding a token = update this table + both init scripts + `tests/` sweep.

## After instantiation

Bucket/container names derived from the project name are defaults, not
mandates — the bootstrap output of each cloud's `bootstrap/<cloud>.md` is the
source of truth; paste those values over the defaults if they differ.
