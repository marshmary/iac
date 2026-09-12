# Bootstrap: GCP state backend (run once)

Creates the versioned GCS state bucket that `backend.tf` expects and enables
the APIs the google provider needs. Do this BEFORE the first
`task init-backend`. Requires the gcloud CLI, `gcloud auth login`, and
`gcloud config set project <project-id>`.

```bash
export PROJECT_ID=<your-gcp-project-id>
export BUCKET="${PROJECT_ID}-tfstate"    # GCS names are global; adjust if taken
export LOCATION=<location>               # multi-region "US"/"EU" or a region e.g. "us-central1"

# 1) APIs needed by the google provider and the GCS backend.
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com
# Expected output: "Operation <name> finished successfully." (~1 min)

# 2) State bucket with versioning — old states stay recoverable. UBLA keeps
#    access control at the bucket level (no per-object ACL surprises).
gcloud storage buckets create "gs://$BUCKET" \
  --project="$PROJECT_ID" \
  --location="$LOCATION" \
  --uniform-bucket-level-access
# Expected output: "Creating gs://<bucket>/ ..." followed by a completion line

gcloud storage buckets update "gs://$BUCKET" --versioning
# Expected output: a line ending in "versioning: Enabled"

echo "STATE_BUCKET=$BUCKET"
```

Keep the bucket private: with UBLA on, grant deployers
`roles/storage.objectAdmin` on the bucket only — do not widen it to the
project.

Then substitute these values in `backend.tf` and `provider.tf`:

| file.field | value |
| ---------- | ----- |
| `backend.tf` → `bucket` | `$BUCKET` |
| `provider.tf` → `project` | `$PROJECT_ID` |
| `provider.tf` → `region` / `starter.tf` → `location` | `$LOCATION` |

Then run: `task init-backend`.
