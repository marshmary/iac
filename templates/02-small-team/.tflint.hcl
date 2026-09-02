# tflint config - `task lint` runs `tflint --init` (once) then `tflint --recursive`.
plugin "terraform" {
  enabled = true
}

# Env roots receive init-merged files (backend.tf, provider.tf, starter.tf,
# dry_run.tf) that intentionally live outside variables.tf/main.tf; the
# standard-structure rule would fight the merge contract.
rule "terraform_standard_module_structure" {
  enabled = false
}

# Stricter rules worth enabling as the team matures - uncomment to adopt:
# rule "terraform_comment_header" {
#   enabled = true
# }
# rule "terraform_unused_declarations" {
#   enabled = true
# }
