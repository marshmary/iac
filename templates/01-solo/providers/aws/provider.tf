# AWS provider — merged into the project root at instantiation.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "__REGION__"

  # Applied to every taggable AWS resource on top of resource-level tags
  # (resource tags win on key conflicts). local.common_tags in main.tf adds
  # the Env tag per resource.
  default_tags {
    tags = {
      Project   = "__PROJECT_NAME__"
      ManagedBy = "iac"
    }
  }

  # dry_run=true lets `task plan-dry` plan OFFLINE with fake credentials:
  #   AWS_ACCESS_KEY_ID=fake AWS_SECRET_ACCESS_KEY=fake task plan-dry
  # These flags skip the startup API calls that would otherwise fail without
  # real credentials. Defaults to false (see dry_run.tf) so real plans and
  # applies still validate credentials and account access instead of hiding
  # breakage.
  skip_credentials_validation = var.dry_run
  skip_requesting_account_id  = var.dry_run
  skip_metadata_api_check     = var.dry_run
}
