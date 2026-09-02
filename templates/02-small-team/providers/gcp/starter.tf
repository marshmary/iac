# Example starter resource - proves the wiring end-to-end.
# REPLACE with real infrastructure; keep the label convention.
# Note: GCS bucket names are globally unique and labels are lowercase-only,
# so the substituted project value must be a lowercase slug.
resource "google_storage_bucket" "starter" {
  name     = "__PROJECT_NAME__-__ENV__-starter"
  location = "__REGION__"

  labels = {
    project   = "__PROJECT_NAME__"
    env       = "__ENV__"
    managedby = "iac"
  }
}
