# Remote state backend - SHARED bucket, one key per env, native S3 locking.
# The bucket and region are created in bootstrap/aws.md.

terraform {
  backend "s3" {
    bucket       = "__STATE_BUCKET__"
    key          = "__PROJECT_NAME__/__ENV__/terraform.tfstate"
    region       = "__REGION__"
    encrypt      = true
    use_lockfile = true
  }
}
