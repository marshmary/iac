# -----------------------------------------------------------------------------
# common/accounts.hcl - account / subscription / project registry.
#
# THIS FILE IS THE SINGLE SOURCE OF TRUTH for "which cloud account does each
# environment deploy into". Every platforms/<cloud>/root.hcl reads it via
# read_terragrunt_config(find_in_parent_folders("common/accounts.hcl")) and
# resolves its own map entry by environment name.
#
# Rules of the house:
#   - never hardcode an account/subscription/project anywhere else;
#   - adding an environment means adding a key here (see
#     runbooks/adding-an-environment.md);
#   - keys MUST match the directory names under platforms/*/envs/.
# -----------------------------------------------------------------------------

locals {
  # AWS account IDs, keyed by environment (12-digit numeric IDs). Per-env
  # tokens so dev and prod can differ; the distinct zero-defaults force a
  # conscious replacement instead of a silent same-account dev/prod.
  aws_accounts = {
    dev  = "__AWS_ACCOUNT_ID_DEV__"
    prod = "__AWS_ACCOUNT_ID_PROD__"
  }

  # Azure subscription GUIDs, keyed by environment.
  azure_subscriptions = {
    dev  = "__AZURE_SUBSCRIPTION_ID_DEV__"
    prod = "__AZURE_SUBSCRIPTION_ID_PROD__"
  }

  # Google Cloud project IDs, keyed by environment.
  gcp_projects = {
    dev  = "__GCP_PROJECT__"
    prod = "__GCP_PROJECT__"
  }
}
