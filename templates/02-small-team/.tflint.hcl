# tflint config - `task lint` runs `tflint --init` (once) then `tflint --recursive`.
plugin "terraform" {
  enabled = true
}

# Stricter rules worth enabling as the team matures - uncomment to adopt:
# rule "terraform_comment_header" {
#   enabled = true
# }
# rule "terraform_unused_declarations" {
#   enabled = true
# }
