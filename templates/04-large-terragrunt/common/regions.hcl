# -----------------------------------------------------------------------------
# common/regions.hcl - region registry.
#
# Single source of truth for "where does each cloud deploy by default". Each
# platforms/<cloud>/root.hcl reads the *_primary value for its cloud via
# read_terragrunt_config and exposes it to components as a local
# (region / location / region respectively for aws / azure / gcp).
#
# This template pins ONE primary region per cloud. Multi-region expansion:
# add entries here (e.g. aws_secondary) and read them in the root.hcl of the
# platform that needs them - components then select via locals, never via
# hardcoded strings.
# -----------------------------------------------------------------------------

locals {
  # Literal defaults per cloud: one file serves all three clouds, and the
  # initializer cannot substitute a single region token three ways.
  aws_primary   = "us-east-1"
  azure_primary = "eastus"
  gcp_primary   = "us-central1"
}
