# Azure backend + provider generation.
#
# Injected into root.hcl between the CLOUD PROVIDER markers by
# scripts/init-project.{sh,ps1} (-Provider azure).
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
  backend "azurerm" {
    resource_group_name  = "__STATE_RESOURCE_GROUP__"
    storage_account_name = "__STATE_STORAGE_ACCOUNT__"
    container_name       = "__STATE_CONTAINER__"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# Uncomment when a component uses real Azure resources (kept commented so
# provider-free components like baseline plan fully offline).
# Authenticate via ARM_* environment variables (see .env.example):
#   ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
# provider "azurerm" {
#   features {}
# }
EOF
}
