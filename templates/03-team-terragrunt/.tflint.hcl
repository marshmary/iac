# TFLint configuration — applies to the Terraform/OpenTofu modules under
# modules/ (the baseline module is deliberately provider-free, so only the
# core terraform plugin is enabled).
plugin "terraform" {
  enabled = true
}
