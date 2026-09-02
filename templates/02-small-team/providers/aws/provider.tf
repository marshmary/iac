terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "__REGION__"

  # Project convention tags - applied to every taggable resource in this env.
  default_tags {
    tags = {
      Project   = "__PROJECT_NAME__"
      Env       = "__ENV__"
      ManagedBy = "iac"
    }
  }

  # dry_run (declared in envs/<env>/variables.tf, default false) makes the
  # provider skip its credential/account-ID round trips so `task plan-dry`
  # runs without cloud API calls, e.g.:
  #   AWS_ACCESS_KEY_ID=fake AWS_SECRET_ACCESS_KEY=fake task plan-dry ENV=dev
  # Keep dry_run = false for real plans/applies - these skips are offline-only
  # conveniences, never for production use.
  skip_credentials_validation = var.dry_run
  skip_requesting_account_id  = var.dry_run
  skip_metadata_api_check     = var.dry_run
}
