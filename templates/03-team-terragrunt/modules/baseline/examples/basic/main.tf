# Smallest working example of the baseline module.
module "baseline" {
  source = "../.."

  project     = "example"
  environment = "dev"
}

output "name_prefix" {
  description = "Rendered naming prefix."
  value       = module.baseline.name_prefix
}

output "tags" {
  description = "Rendered identity tags."
  value       = module.baseline.tags
}
