# Provider-free bootstrap used by playground/up.sh to create the S3 state
# bucket + DynamoDB lock table INSIDE LocalStack before the first apply.
# The real backend.tf in the project root points at the bucket/table made here.
#
# LocalStack emulates S3 + DynamoDB, so this runs fully offline:
#     AWS_ENDPOINT_URL=http://localhost:4566 \
#     AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
#     tofu init -backend=false && tofu apply -auto-approve
#
# Kept out of the generated project's normal apply graph: this directory is
# created by up.sh and is disposable (playground/projects/ is gitignored).

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  # Skip real-account discovery: LocalStack accepts any credentials.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  # LocalStack serves S3 on a single edge endpoint (localhost:4566) but the
  # provider otherwise resolves virtual-hosted bucket URLs
  # (bucket.localhost -> wrong host). Path-style puts the bucket in the URL
  # path where LocalStack can route it. (Equivalent env: S3_FORCE_PATH_STYLE.)
  s3_use_path_style = true
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "bucket" {
  description = "Name of the S3 bucket that will hold remote state."
  type        = string
}

variable "table" {
  description = "Name of the DynamoDB lock table."
  type        = string
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = var.table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
