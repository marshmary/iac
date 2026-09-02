# Bootstrap: AWS state backend (run once)

Creates the S3 state bucket and DynamoDB lock table that `backend.tf` expects.
Do this BEFORE the first `task init-backend`. Requires the aws CLI v2 and
credentials with permission to create S3 + DynamoDB resources.

```bash
export AWS_REGION=<your-region>           # e.g. eu-west-1
export PROJECT=<your-project-name>        # the slug you instantiated with
export BUCKET="$PROJECT-tfstate"          # S3 names are global; append your account id if taken
export TABLE="$PROJECT-tflock"

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

# 2) Lock table — on-demand billing; the LockID key is what backend "s3" expects.
aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
# Expected output: JSON with "TableStatus": "CREATING" — active within ~30s.

echo "STATE_BUCKET=$BUCKET  LOCK_TABLE=$TABLE  REGION=$AWS_REGION"
```

Then substitute these values in `backend.tf` (and set the region in `provider.tf`):

| backend.tf field | value |
| ---------------- | ----- |
| `bucket` | `$BUCKET` |
| `dynamodb_table` | `$TABLE` |
| `region` | `$AWS_REGION` |

Then run: `task init-backend`.
