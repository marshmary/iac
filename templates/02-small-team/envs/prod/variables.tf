variable "project" {
  type        = string
  description = "Project slug used in resource names and tags (set per env in <env>.tfvars)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project))
    error_message = "project must be 3-32 chars of lowercase letters, digits and hyphens, starting and ending alphanumeric."
  }
}
