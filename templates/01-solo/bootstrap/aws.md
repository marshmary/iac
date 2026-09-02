# Bootstrap: AWS state backend (run once)

Creates the S3 state bucket that `backend.tf` expects. State locking is
S3-native (`use_lockfile = true`), so no DynamoDB table is required. Do this
BEFORE the first `task init-backend`. Requires the aws CLI v2 and credentials
with permission to create S3 resources.

```bash
export AWS_REGION=<your-region>           # e.g. eu-west-1
export PROJECT=<your-project-name>        # the slug you instantiated with
export BUCKET="$PROJECT-tfstate"          # S3 names are global; append your account id if taken

# 1) State bucket — versioning keeps old states recoverable; encrypted at rest.
#    NOTE: in us-east-1 you must DROP the --create-bucket-configuration flag.
aws s3api create-bucket --bucket "$BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"
# Expected output: {"Location": "/<bucket-name>"}

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
# Expected output: none (empty)

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
# Expected output: none (empty)

echo "STATE_BUCKET=$BUCKET  REGION=$AWS_REGION"
```

Then substitute these values in `backend.tf` (and set the region in `provider.tf`):

| backend.tf field | value |
| ---------------- | ----- |
| `bucket` | `$BUCKET` |
| `region` | `$AWS_REGION` |

## Optional: lifecycle rule for lock objects

S3-native locking writes a `<key>.tflock` object on every lock/unlock. On a
versioned bucket that accumulates lock-object versions; add a lifecycle rule
to expire noncurrent `.tflock` versions (and old state versions) after a few
days if you want to keep version counts down.

Then run: `task init-backend`.
