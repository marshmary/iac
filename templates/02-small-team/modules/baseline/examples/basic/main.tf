# Minimal usage of the baseline module.
module "baseline" {
  source      = "../.."
  project     = "my-app"
  environment = "dev"
}

output "name_prefix" {
  value = module.baseline.name_prefix
}
