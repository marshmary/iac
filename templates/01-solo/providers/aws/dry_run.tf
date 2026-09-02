# AWS-only variable, merged into the project root together with this
# provider layer. Azure/GCP providers phone home while configuring, so they
# get no offline-plan flag and no dry_run variable.

variable "dry_run" {
  description = "Flips the provider skip_* flags so `task plan-dry` can plan offline with fake credentials. Must stay false for real plans and applies."
  type        = bool
  default     = false
}
