variable "project" {
  type        = string
  description = "Project slug used as the first segment of every resource name."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project))
    error_message = "project must be 3-32 chars of lowercase letters, digits and hyphens, starting and ending alphanumeric."
  }
}

variable "environment" {
  type        = string
  description = "Environment slug (dev, staging, prod, ...) used as the second name segment."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,14}$", var.environment))
    error_message = "environment must be a short lowercase slug (e.g. dev, staging, prod)."
  }
}
