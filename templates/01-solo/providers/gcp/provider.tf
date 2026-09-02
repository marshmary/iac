# Google Cloud provider — merged into the project root at instantiation.
terraform {
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
}

# Authentication via Application Default Credentials:
#   human:       gcloud auth application-default login
#   automation:  GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json
# (names listed in .env.example)
