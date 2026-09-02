# Example resource — REPLACE with real infrastructure, then delete this file.
# location accepts a multi-region ("US", "EU") or a region ("us-central1"):
# substitute whichever you chose for the region token.
# NOTE: GCP label keys must be lowercase — derive them from common_tags
# instead of hand-maintaining a second tag map.
resource "google_storage_bucket" "starter" {
  name     = "__PROJECT_NAME__-starter"
  location = "__REGION__"

  labels = { for k, v in local.common_tags : lower(k) => v }
}
