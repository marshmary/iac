output "conventions" {
  description = "Rendered name prefix — proves the locals conventions resolve."
  value       = terraform_data.conventions.output
}

output "starter_instructions" {
  description = "Next steps after the first apply."
  value       = <<-EOT
    Conventions look good. Next:
      1. Replace terraform_data.conventions in main.tf with real resources.
      2. Use starter.tf (merged in from providers/) as the first-resource example, then delete it.
      3. Iterate: task plan ENV=${var.environment} -> review -> task apply.
  EOT
}
