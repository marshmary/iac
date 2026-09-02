variable "project" {
  description = "Project slug used in resource names and tags. Supplied via dev.tfvars/prod.tfvars (no default on purpose: forces an explicit choice)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.project))
    error_message = "project must be kebab-case (lowercase alphanumerics and single hyphens, 1-63 chars, no leading/trailing hyphen) so cloud name limits hold."
  }
}

variable "environment" {
  description = "Environment name; must match a <environment>.tfvars file. Drives the name prefix and tags."
  type        = string
  default     = "dev"
}
