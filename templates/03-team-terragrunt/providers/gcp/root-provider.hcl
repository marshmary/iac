# GCP backend + provider generation.
#
# Injected into root.hcl between the CLOUD PROVIDER markers by
# scripts/init-project.{sh,ps1} (-Provider gcp).
#
# `generate` blocks are inherited by every unit that includes root.hcl and
# are materialised as backend.tf / provider.tf inside each unit's
# .terragrunt-cache working directory at runtime (never committed).
#
# The GCS backend uses `prefix` (not `key`); it is set to
# path_relative_to_include() — the unit's path relative to the included
# root.hcl — so each component gets its own state namespace, e.g.
# envs/dev/baseline/ (state file default.tfstate inside it).

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "gcs" {
    bucket = "__STATE_BUCKET__"
    prefix = "${path_relative_to_include()}"
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# Uncomment when a component uses real GCP resources (kept commented so
# provider-free components like baseline plan fully offline). Authenticate
# via GOOGLE_APPLICATION_CREDENTIALS (see .env.example):
# provider "google" {
#   project = "__GCP_PROJECT__"
#   region  = "__REGION__"
# }
EOF
}
