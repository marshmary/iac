variable "project" {
  description = "Project slug used to build the name prefix and identity tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.project))
    error_message = "project must be lowercase alphanumerics and dashes, starting alphanumeric."
  }
}

variable "environment" {
  description = "Environment slug (dev, prod) used in the name prefix and identity tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.environment))
    error_message = "environment must be lowercase alphanumerics and dashes, starting alphanumeric."
  }
}

variable "name_prefix" {
  description = "Explicit prefix override; defaults to \"<project>-<environment>\"."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags merged over the module identity tags."
  type        = map(string)
  default     = {}
}
