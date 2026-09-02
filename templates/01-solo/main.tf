# Naming and tagging conventions for the whole project.
#
# Every real resource added later should derive names from local.name_prefix
# and apply local.common_tags (AWS/Azure tag keys). GCP label keys must be
# lowercase — see starter.tf for the per-cloud spelling. Replace the
# terraform_data placeholder below with real infrastructure once the
# conventions render the way you want.

locals {
  project     = var.project
  environment = var.environment

  # Resource name prefix, e.g. "my-app-dev".
  name_prefix = "${var.project}-${var.environment}"

  # Mandatory tags for every taggable resource.
  common_tags = {
    Project   = var.project
    Env       = var.environment
    ManagedBy = "iac"
  }
}

# Placeholder resource: renders the conventions into plans and outputs without
# creating anything. terraform_data is built into Terraform (>= 1.4) and
# OpenTofu, so it needs no cloud credentials and no provider download.
# REPLACE THIS with real infrastructure (starter.tf has a per-cloud example).
resource "terraform_data" "conventions" {
  input = local.name_prefix
}
