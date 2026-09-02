# Remote state: S3 bucket with native state locking (use_lockfile).
# Create the bucket before the first `task init-backend` — copy-paste commands
# in bootstrap/aws.md — then fill in the placeholder values printed there.
terraform {
  backend "s3" {
    bucket       = "__STATE_BUCKET__"
    key          = "__PROJECT_NAME__/terraform.tfstate"
    region       = "__REGION__"
    encrypt      = true
    use_lockfile = true
  }
}
