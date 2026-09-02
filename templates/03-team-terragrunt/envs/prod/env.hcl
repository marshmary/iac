# prod environment locals.
#
# root.hcl discovers this file with find_in_parent_folders("env.hcl") and
# derives the environment name from its parent directory (prod). Units that
# need more than the name can read these locals directly:
#
#   env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
locals {
  env              = "prod"
  environment_tier = "prod"
}
