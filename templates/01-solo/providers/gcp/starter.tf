# Example resource — REPLACE with real infrastructure, then delete this file.
# location accepts a multi-region ("US", "EU") or a region ("us-central1"):
# substitute whichever you chose for the region token.
# NOTE: GCP label keys must be lowercase, which is why this does not reuse
# local.common_tags (TitleCase keys) — keep the lowercase equivalents instead.
resource "google_storage_bucket" "starter" {
  name     = "__PROJECT_NAME__-starter"
  location = "__REGION__"

  labels = {
    project    = "__PROJECT_NAME__"
    env        = local.environment
    managed-by = "iac"
  }
}
