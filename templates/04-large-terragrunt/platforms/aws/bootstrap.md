# platforms/aws - bootstrap one-pager

Run ONCE per AWS organization, before the first `task plan`. Creates the
remote-state bucket that `root.hcl`'s generated backend references. Locking is
S3-native (`use_lockfile = true`), so no DynamoDB table is needed. These
resources are deliberately NOT managed in-tree - they bootstrap the bootstrap.

## 0. Authenticate

```bash
aws sso login                 # or: aws configure for static keys
aws sts get-caller-identity   # confirm the identity you expect
```

For non-interactive environments see the AWS block in `.env.example`
(`AWS_ROLE_ARN`, and the `AWS_WEB_IDENTITY_TOKEN_FILE` OIDC placeholders for
CI later).

## 1. Create the state bucket

```bash
aws s3api create-bucket --bucket __STATE_BUCKET__ --region __REGION__ \
  --create-bucket-configuration LocationConstraint=__REGION__
# NOTE: for us-east-1 OMIT --create-bucket-configuration entirely.

aws s3api put-bucket-versioning --bucket __STATE_BUCKET__ \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket __STATE_BUCKET__ \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket __STATE_BUCKET__ \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Versioning is not optional: it is your undo button for state incidents
(`runbooks/state-incident.md`).

## 2. Lifecycle rule for lock objects (recommended)

S3-native locking writes a `<key>.tflock` object on every lock/unlock. On a
versioned bucket that accumulates lock-object versions; add a lifecycle rule
to expire noncurrent `.tflock` versions (and old state versions) after a few
days to keep version counts down.

## 3. First run

```bash
task engine-check
task hcl-validate PLATFORM=aws ENV=dev COMPONENT=baseline
task plan PLATFORM=aws ENV=dev COMPONENT=baseline
task policy-check PLATFORM=aws ENV=dev COMPONENT=baseline
task apply PLATFORM=aws ENV=dev COMPONENT=baseline
```

The first `plan` writes the initial state key
`envs/dev/baseline/terraform.tfstate` into the bucket - no pre-seeding needed;
keys inherit the `envs/<env>/<component>` pattern automatically.

## CI note (for later)

When you wire CI, authenticate via OIDC: `AWS_WEB_IDENTITY_TOKEN_FILE` +
`AWS_ROLE_ARN` (placeholders in `.env.example`). Never put static keys in the
pipeline. Permissions floor: read/write on the bucket prefix (state and
`.tflock` lock objects), `sts:AssumeRole` where applicable.
