# Engine constraint only.
# required_providers deliberately lives in provider.tf (merged in from
# providers/<cloud>/ at instantiation) so this project stays single-cloud.
# The block name "terraform" is identical under both terraform and tofu.
terraform {
  required_version = ">= 1.11.0, < 2.0.0"
}
