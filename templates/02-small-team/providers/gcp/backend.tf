# Remote state backend - SHARED bucket, one prefix per env.
# The bucket is created in bootstrap/gcp.md; credentials come from the same
# GOOGLE_* environment / ADC chain as the provider.

terraform {
  backend "gcs" {
    bucket = "__STATE_BUCKET__"
    prefix = "__PROJECT_NAME__/__ENV__"
  }
}
