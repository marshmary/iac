# -----------------------------------------------------------------------------
# platforms/aws/root.hcl - shared Terragrunt config for the ENTIRE AWS tree.
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
#   - resolve account_id from common/accounts.hcl (THE registry - never
#     hardcode account IDs in components)
#   - resolve region from common/regions.hcl
#   - merge mandatory tags (common/tags.hcl) with env context into common_tags
#   - generate the S3 state backend
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

  platform = "aws"

  # Account registry - single source of truth: common/accounts.hcl.
  accounts   = read_terragrunt_config(find_in_parent_folders("common/accounts.hcl"))
  account_id = local.accounts.locals.aws_accounts[local.env]

  # Region registry - single source of truth: common/regions.hcl.
  regions = read_terragrunt_config(find_in_parent_folders("common/regions.hcl"))
  region  = local.regions.locals.aws_primary

  # Tag policy definition - single source of truth: common/tags.hcl.
  # policy/tags.rego enforces exactly these keys at plan time.
  tags_config    = read_terragrunt_config(find_in_parent_folders("common/tags.hcl"))
  mandatory_tags = local.tags_config.locals.mandatory_tags

  common_tags = merge(
    local.mandatory_tags,
    {
      Platform = local.platform
      Env      = local.env
      Tier     = local.tier
      Account  = local.account_id
    },
  )
}

# State backend. The key is the component path relative to this file
# (envs/<env>/<component>), so with this platform's dedicated bucket the
# logical state address is <platform>/envs/<env>/<component>/terraform.tfstate.
# Provision the bucket once via bootstrap.md - it is deliberately NOT managed
# in-tree. Locking is S3-native (use_lockfile), no DynamoDB table needed.
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket       = "__STATE_BUCKET__"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "__REGION__"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
}

# The provider block below is intentionally COMMENTED OUT.
#
# Why: provider-free components (baseline) must `terragrunt plan` fully
# offline - no AWS credentials, no provider downloads at plan time. When a
# component starts creating real resources, uncomment the block (or override
# the generated file in that component) and re-run `task policy-check`:
# default_tags wired to common_tags below auto-satisfies policy/tags.rego
# for taggable AWS resources. For role assumption / OIDC env vars see
# .env.example and bootstrap.md.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# ---------------------------------------------------------------------------
# Provider kept commented on purpose: provider-free components (baseline)
# plan fully offline. Uncomment per component when real resources land.
# ---------------------------------------------------------------------------
# provider "aws" {
#   region = "${local.region}"
#
#   default_tags {
#     tags = ${jsonencode(local.common_tags)}
#   }
# }
EOF
}
