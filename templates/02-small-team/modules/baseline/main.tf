# Baseline convention module - the reference shape for new modules.
# Cloud-neutral by design: no providers, plans and tests fully offline.

locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project   = var.project
      Env       = var.environment
      ManagedBy = "iac"
    },
    var.tags,
  )
}

# terraform_data needs no provider, so it renders the naming convention into
# the plan/test output as a real managed resource without any cloud access.
resource "terraform_data" "this" {
  input = local.name_prefix
}
