# -----------------------------------------------------------------------------
# platforms/azure/root.hcl - shared Terragrunt config for the ENTIRE Azure tree.
#
# Every component includes this file:
#
#   include "root" {
#     path   = find_in_parent_folders("root.hcl")
#     expose = true
#   }
#
# Responsibilities:
#   - resolve env/tier from the nearest env.hcl (envs/<env>/env.hcl)
#   - resolve subscription_id from common/accounts.hcl (THE registry - never
#     hardcode subscription IDs in components)
#   - resolve location from common/regions.hcl
#   - merge mandatory tags (common/tags.hcl) with env context into common_tags
#   - generate the azurerm state backend
#   - generate the provider block (COMMENTED - see the block itself)
#
# Components read everything as include.root.locals.* thanks to expose = true.
# -----------------------------------------------------------------------------

locals {
  project = "__PROJECT_NAME__"

  # Nearest env.hcl going up from the component (envs/<env>/env.hcl).
  env_config = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env        = local.env_config.locals.env
  tier       = local.env_config.locals.tier

  platform = "azure"

  # Subscription registry - single source of truth: common/accounts.hcl.
  accounts        = read_terragrunt_config(find_in_parent_folders("common/accounts.hcl"))
  subscription_id = local.accounts.locals.azure_subscriptions[local.env]

  # Region registry - single source of truth: common/regions.hcl.
  regions  = read_terragrunt_config(find_in_parent_folders("common/regions.hcl"))
  location = local.regions.locals.azure_primary

  # Tag policy definition - single source of truth: common/tags.hcl.
  # policy/tags.rego enforces exactly these keys at plan time.
  tags_config    = read_terragrunt_config(find_in_parent_folders("common/tags.hcl"))
  mandatory_tags = local.tags_config.locals.mandatory_tags

  common_tags = merge(
    local.mandatory_tags,
    {
      Platform     = local.platform
      Env          = local.env
      Tier         = local.tier
      Subscription = local.subscription_id
    },
  )
}

# State backend. The key is the component path relative to this file
# (envs/<env>/<component>), so with this platform's dedicated storage account
# the logical state address is <platform>/envs/<env>/<component>/terraform.tfstate.
# Provision the resource group + storage account + container once via
# bootstrap.md - they are deliberately NOT managed in-tree.
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

# The provider block below is intentionally COMMENTED OUT.
#
# Why: provider-free components (baseline) must `terragrunt plan` fully
# offline - no Azure credentials, no provider downloads at plan time. When a
# component starts creating real resources, uncomment the block (or override
# the generated file in that component) and re-run `task policy-check`:
# azurerm picks tags up from component inputs, so keep passing
# include.root.locals.common_tags into the module's tags argument. For
# authentication see the ARM_* notes below, .env.example and bootstrap.md.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# ---------------------------------------------------------------------------
# Provider kept commented on purpose: provider-free components (baseline)
# plan fully offline. Uncomment per component when real resources land.
#
# Authentication is via ARM_* environment variables (see .env.example):
#   ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
# (or ARM_USE_OIDC=true with workload identity federation for CI later).
# ---------------------------------------------------------------------------
# provider "azurerm" {
#   features {}
#
#   subscription_id = "${local.subscription_id}"
# }
EOF
}
