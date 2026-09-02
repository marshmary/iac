output "name_prefix" {
  description = "Resource naming prefix for this component."
  value       = local.name_prefix
}

output "tags" {
  description = "Identity tags to apply to this component's resources."
  value       = local.tags
}
