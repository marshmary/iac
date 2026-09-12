# Bootstrap: AWS state backend (once per project)

Creates the SHARED backend - one S3 bucket. Every env (`envs/dev|staging|prod`)
stores its state under its own key in the same bucket. Do NOT create per-env
buckets. State locking is S3-native (`use_lockfile = true`), so no DynamoDB
table is required.

```bash
export AWS_REGION=eu-west-1            # region for state + provider
PROJECT=my-app                         # must match the project name used at init
BUCKET=my-app-tfstate                  # S3 names are globally unique - adjust

# State bucket: versioned, encrypted, public access blocked
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

Then substitute these values in every `envs/*/backend.tf` (and the region in
each `envs/*/provider.tf`): the bucket name and the region replace their
placeholder tokens in those files. Run this once - the backend is shared by
all envs.

## Optional: lifecycle rule for lock objects

S3-native locking writes a `<key>.tflock` object on every lock/unlock. On a
versioned bucket that accumulates lock-object versions; add a lifecycle rule
to expire noncurrent `.tflock` versions (and old state versions) after a few
days if you want to keep version counts down.
