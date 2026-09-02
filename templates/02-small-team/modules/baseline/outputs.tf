output "name_prefix" {
  description = "Convention prefix: <project>-<environment>."
  value       = local.name_prefix
}

output "tags" {
  description = "Convention tags applied alongside provider-level default tags."
  value       = local.tags
}
