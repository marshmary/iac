# Bootstrap: GCP state backend (once per project)

Creates the SHARED backend - one GCS bucket. Every env stores its state under
its own prefix in the same bucket. Do NOT create per-env buckets.

```bash
# Enable required APIs (once per GCP project)
gcloud services enable storage.googleapis.com

PROJECT_ID=my-gcp-project              # hosts state AND deploys
REGION=europe-west1
BUCKET=my-gcp-project-tfstate          # GCS names are globally unique - adjust

gcloud storage buckets create "gs://$BUCKET" \
  --project="$PROJECT_ID" --location="$REGION" \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://$BUCKET" --versioning
```

Authenticate with Application Default Credentials
(`gcloud auth application-default login`) or point
`GOOGLE_APPLICATION_CREDENTIALS` at a key file (never commit it).

Then substitute these values in every `envs/*/backend.tf` (and the project +
region in each `envs/*/provider.tf`): the bucket name, the GCP project id and
the region replace their placeholder tokens in those files. Run this once -
the backend is shared by all envs.
