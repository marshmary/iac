# -----------------------------------------------------------------------------
# platforms/gcp/root.hcl - shared Terragrunt config for the ENTIRE GCP tree.
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
#   - resolve project_id from common/accounts.hcl (THE registry - never
#     hardcode project IDs in components)
#   - resolve region from common/regions.hcl
#   - merge mandatory tags (common/tags.hcl) with env context into common_tags
#   - generate the GCS state backend
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

  platform = "gcp"

  # Project registry - single source of truth: common/accounts.hcl.
  accounts   = read_terragrunt_config(find_in_parent_folders("common/accounts.hcl"))
  project_id = local.accounts.locals.gcp_projects[local.env]

  # Region registry - single source of truth: common/regions.hcl.
  regions = read_terragrunt_config(find_in_parent_folders("common/regions.hcl"))
  region  = local.regions.locals.gcp_primary

  # Tag policy definition - single source of truth: common/tags.hcl.
  # policy/tags.rego enforces exactly these keys at plan time (GCP resources
  # carry them in their `labels` map).
  tags_config    = read_terragrunt_config(find_in_parent_folders("common/tags.hcl"))
  mandatory_tags = local.tags_config.locals.mandatory_tags

  common_tags = merge(
    local.mandatory_tags,
    {
      Platform    = local.platform
      Environment = local.env
      Tier        = local.tier
      Project     = local.project_id
    },
  )
}

# State backend. The prefix is the component path relative to this file
# (envs/<env>/<component>), so with this platform's dedicated bucket the
# logical state address is <platform>/envs/<env>/<component>/terraform.tfstate.
# Provision the bucket once via bootstrap.md - it is deliberately NOT managed
# in-tree.
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "gcs" {
    bucket = "__STATE_BUCKET__"
    prefix = "${path_relative_to_include()}"
  }
}
EOF
}

# The provider block below is intentionally COMMENTED OUT.
#
# Why: provider-free components (baseline) must `terragrunt plan` fully
# offline - no Google credentials, no provider downloads at plan time. When a
# component starts creating real resources, uncomment the block (or override
# the generated file in that component) and re-run `task policy-check`:
# keep passing include.root.locals.common_tags into the module's labels-style
# inputs so taggable resources carry the mandatory keys. For authentication
# see the GOOGLE_* notes below, .env.example and bootstrap.md.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# ---------------------------------------------------------------------------
# Provider kept commented on purpose: provider-free components (baseline)
# plan fully offline. Uncomment per component when real resources land.
#
# Authentication: GOOGLE_APPLICATION_CREDENTIALS (application-default login
# locally, see .env.example); for CI later use workload identity federation
# (GOOGLE_ALLOW_WORKLOAD_IDENTITY, no key files in the pipeline).
# ---------------------------------------------------------------------------
# provider "google" {
#   project = "${local.project_id}"
#   region  = "${local.region}"
# }
EOF
}
