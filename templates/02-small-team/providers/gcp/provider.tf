terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "__GCP_PROJECT__"
  region  = "__REGION__"

  # Authentication via Application Default Credentials or a key file (never
  # commit keys - .env is gitignored):
  #   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/key.json
  # or: gcloud auth application-default login
}
