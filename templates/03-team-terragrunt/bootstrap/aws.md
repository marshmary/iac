# Bootstrap — AWS (one-time, before the first apply)

Creates the shared remote-state backend every environment in this repo
uses: one S3 bucket for state plus one DynamoDB table for locking. The
values you choose here land in the injected backend block in `root.hcl`
(bucket, table and region placeholders are substituted by
`scripts/init-project` at project creation).

## Prerequisites

- AWS CLI v2 installed and authenticated with permission to create S3 and
  DynamoDB resources: `aws sts get-caller-identity`

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

## 2. Lock table

```bash
export TABLE=<dynamo-table-name>         # e.g. <project>-tfstate-locks

aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
```

## 3. First run

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
