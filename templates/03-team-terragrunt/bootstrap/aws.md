# Bootstrap — AWS (one-time, before the first apply)

Creates the shared remote-state backend every environment in this repo
uses: one S3 bucket for state with S3-native locking (`use_lockfile = true`),
so no DynamoDB table is needed. The values you choose here land in the
injected backend block in `root.hcl` (bucket and region placeholders are
substituted by `scripts/init-project` at project creation).

## Prerequisites

- AWS CLI v2 installed and authenticated with permission to create S3
  resources: `aws sts get-caller-identity`

## 1. State bucket

```bash
export AWS_REGION=eu-west-1              # your region
export BUCKET=<globally-unique-name>     # e.g. <project>-tfstate-<suffix>

aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

## 2. First run

Credentials come from the standard AWS chain (env vars, SSO, profiles) —
see `.env.example` for the env-var variant. The engine binary (tofu or
terraform) and terragrunt are resolved automatically by the tasks.

```bash
task engine-check
task init-backend ENV=dev      # terragrunt init — wires the remote backend
task plan ENV=dev              # review the plan
task apply ENV=dev             # apply exactly what was reviewed
task run-all-plan ENV=dev      # once more components exist
```

## Optional: lifecycle rule for lock objects

S3-native locking writes a `<key>.tflock` object on every lock/unlock. On a
versioned bucket that accumulates lock-object versions; add a lifecycle rule
to expire noncurrent `.tflock` versions (and old state versions) after a few
days if you want to keep version counts down.
