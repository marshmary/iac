# -----------------------------------------------------------------------------
# platforms/azure/envs/prod/baseline - provider-free starter component.
# Copy this directory when adding a component to any env.
# -----------------------------------------------------------------------------

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# DEFAULT: the vendored provider-free baseline - plans offline, no registry
# needed (see modules-local/baseline/README.md). Swap to your registry once
# the iac-modules repo exists - pin a tag, never a branch, and bump the pin
# via PR so reviewers see module changes:
terraform {
  source = "${find_in_parent_folders("root.hcl")}/../../../modules-local/baseline"

  # source = "git::https://github.com/__PROJECT_NAME__/iac-modules.git//baseline?ref=v0.0.0"
}

inputs = {
  project     = include.root.locals.project
  environment = include.root.locals.env

  # Mandatory set (common/tags.hcl) + env context, merged in root.hcl.
  tags = include.root.locals.common_tags

  # Real components consume the registries the same way - declare matching
  # variables in your module, e.g.:
  # subscription_id = include.root.locals.subscription_id
  # location        = include.root.locals.location
}
