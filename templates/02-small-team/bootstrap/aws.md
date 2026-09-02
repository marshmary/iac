# Bootstrap: AWS state backend (once per project)

Creates the SHARED backend - one S3 bucket + one DynamoDB lock table. Every
env (`envs/dev|staging|prod`) stores its state under its own key in the same
bucket. Do NOT create per-env buckets.

```bash
export AWS_REGION=eu-west-1            # region for state + provider
PROJECT=my-app                         # must match the project name used at init
BUCKET=my-app-tfstate                  # S3 names are globally unique - adjust
TABLE=my-app-tfstate-locks

# State bucket: versioned, public access blocked
aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Lock table: on-demand billing; the attribute name `LockID` is REQUIRED (exact)
aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then substitute these values in every `envs/*/backend.tf` (and the region in
each `envs/*/provider.tf`): the bucket name, the lock table name and the
region replace their placeholder tokens in those files. Run this once - the
backend is shared by all envs.
