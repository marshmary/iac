# Remote state: GCS bucket.
# Create and version the bucket before the first `task init-backend` —
# copy-paste commands in bootstrap/gcp.md — then fill in the placeholder
# values printed there.
terraform {
  backend "gcs" {
    bucket = "__STATE_BUCKET__"
    prefix = "__PROJECT_NAME__"
  }
}
