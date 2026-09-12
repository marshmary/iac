locals {
  # Naming convention: <project>-<environment> prefixes every resource in
  # this repo. Override with var.name_prefix when a component must diverge.
  name_prefix = coalesce(var.name_prefix, "${var.project}-${var.environment}")

  tags = merge(
    {
      Project   = var.project
      Env       = var.environment
      ManagedBy = "iac"
    },
    var.tags,
  )
}

# Cloud-neutral placeholder so the component plans and applies with zero
# providers and zero credentials — it only renders the convention. Replace
# with real resources as this module grows (keep the same inputs/outputs
# contract so units do not churn).
resource "terraform_data" "this" {
  input = {
    name_prefix = local.name_prefix
    tags        = local.tags
  }
}
