# Passthrough of the shared baseline module outputs.
output "name_prefix" {
  description = "Convention name prefix for this environment."
  value       = module.baseline.name_prefix
}

output "tags" {
  description = "Convention tags for this environment."
  value       = module.baseline.tags
}
