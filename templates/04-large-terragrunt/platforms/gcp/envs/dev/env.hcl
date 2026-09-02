# Environment locals - platforms/gcp/envs/dev.
# Read by root.hcl (find_in_parent_folders("env.hcl")); keep key names stable.

locals {
  env  = "dev"
  tier = "nonprod"
}
