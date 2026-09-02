# AWS backend + provider generation.
#
# Injected into root.hcl between the CLOUD PROVIDER markers by
# scripts/init-project.{sh,ps1} (-Provider aws).
#
# `generate` blocks are inherited by every unit that includes root.hcl and
# are materialised as backend.tf / provider.tf inside each unit's
# .terragrunt-cache working directory at runtime (never committed).
#
# `key` uses path_relative_to_include() — the unit's path relative to the
# included root.hcl — so each component gets its own state file, e.g.
# envs/dev/baseline/terraform.tfstate.

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket         = "__STATE_BUCKET__"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "__REGION__"
    dynamodb_table = "__DYNAMO_TABLE__"
    encrypt        = true
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# Uncomment when a component uses real AWS resources (kept commented so
# provider-free components like baseline plan fully offline):
# provider "aws" {
#   region = "__REGION__"
#   default_tags { tags = { Project = "__PROJECT_NAME__", ManagedBy = "iac" } }
# }
EOF
}
