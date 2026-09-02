# -----------------------------------------------------------------------------
# platforms/aws/envs/prod/baseline - provider-free starter component.
# Copy this directory when adding a component to any env.
# -----------------------------------------------------------------------------

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

###############################################################################
#                                                                             #
#  MODULE SOURCE PLACEHOLDER - READ BEFORE YOUR FIRST PLAN                    #
#                                                                             #
#  Modules are NOT vendored in this repository. They live in a separate       #
#  module registry repo, pinned by tag. Replace the placeholder URL below    #
#  with YOUR registry:                                                        #
#                                                                             #
#    git::https://github.com/__PROJECT_NAME__/iac-modules.git//baseline?ref=v0.0.0 #
#                                                                             #
#  Rules:                                                                     #
#    - always pin ?ref=vX.Y.Z (a tag), never a branch;                        #
#    - bump the pin via PR so reviewers see module changes;                   #
#    - local escape hatch if you choose to vendor instead:                    #
#                                                                             #
#      source = "${find_in_parent_folders("root.hcl")}/../../../modules-local/baseline" #
#                                                                             #
#      (resolves to <repo-root>/modules-local/baseline - create that tree     #
#      and git-ignore nothing in it; it becomes reviewed code like any other) #
#                                                                             #
###############################################################################

terraform {
  source = "git::https://github.com/__PROJECT_NAME__/iac-modules.git//baseline?ref=v0.0.0"
}

inputs = {
  # Naming: <project>-<env>-... - matches policy/naming.rego expectations.
  name_prefix = "${include.root.locals.project}-${include.root.locals.env}"

  # Tags: mandatory set (common/tags.hcl) + env context, merged in root.hcl.
  common_tags = include.root.locals.common_tags

  # Cloud identity from the registries - components never hardcode these.
  account_id = include.root.locals.account_id
  region     = include.root.locals.region
}
