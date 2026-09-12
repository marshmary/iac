variable "project" {
  type        = string
  description = "Project slug used in resource names and tags (set per env in <env>.tfvars)."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.project))
    error_message = "project must be kebab-case (lowercase alphanumerics and single hyphens, 1-63 chars, no leading/trailing hyphen) so cloud name limits hold."
  }
}
