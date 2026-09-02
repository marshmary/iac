# Environment locals - platforms/gcp/envs/prod.
# Read by root.hcl (find_in_parent_folders("env.hcl")); keep key names stable.

locals {
  env  = "prod"
  tier = "prod"
}
