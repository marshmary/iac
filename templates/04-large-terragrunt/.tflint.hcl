# tflint configuration - tier 04 (large multi-team repo = strict ruleset).
#
# The vendored modules under modules-local/ carry real *.tf (registry modules
# are checked in their own repo), so this config is ACTIVE: pre-commit's
# terraform_tflint and the catalog runner lint modules-local/baseline with it.
# Run manually from any directory containing .tf files:
#
#   tflint --config=$(git rev-parse --show-toplevel)/.tflint.hcl
#
# Tier 4 enables the strict rules on top of the defaults:
#   terraform_unused_declarations - dead declarations rot multi-team repos;
#                                   keep them out.
#   terraform_comment_syntax      - uniform # comments (readability at scale).
#
# NOTE: rule names must exist in the terraform ruleset - tflint hard-fails on
# unknown names ("Rule not found"). Do not add aspirational rules here.

plugin "terraform" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}
