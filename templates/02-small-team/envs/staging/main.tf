# Staging root module - cloud-neutral wiring.
# backend.tf / provider.tf / starter.tf (merged in at init) carry everything
# cloud-specific: required_providers, backend and credentials handling.

locals {
  env = "staging"

  # Spread onto resources you add in this env root. Provider-level default
  # tags live in provider.tf and already cover taggable managed resources.
  common_tags = {
    Project   = var.project
    Env       = local.env
    ManagedBy = "iac"
  }
}

module "baseline" {
  source      = "../../modules/baseline"
  project     = var.project
  environment = local.env
}
