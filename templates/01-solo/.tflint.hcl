# Base tflint config: engine-neutral rules from the "terraform" plugin, so
# linting works offline with no cloud credentials and no cloud plugin.
# One-time setup: `tflint --init` (downloads the plugin), then `task lint`.
# When you outgrow this, add the plugin matching provider.tf (aws/azurerm/
# google) for provider-aware rules: https://github.com/terraform-linters
plugin "terraform" {
  enabled = true
}

# The init-merged cloud layer keeps its variables/resources in their own
# files (dry_run.tf, starter.tf, backend.tf); the standard-structure rule
# would demand variables.tf/main.tf and fight the merge contract.
rule "terraform_standard_module_structure" {
  enabled = false
}
