# Bootstrap — GCP (one-time, before the first apply)

Creates the shared remote-state backend every environment in this repo
uses: one versioned GCS bucket. The values you choose here land in the
injected backend block in `root.hcl` (project, region and bucket
placeholders are substituted by `scripts/init-project` at project creation).

## Prerequisites

- gcloud CLI installed: `gcloud auth login`
- A project with billing enabled, then enable the APIs needed for state
  storage (enable others as you add real resources):

```bash
gcloud config set project <project-id>
gcloud services enable storage.googleapis.com
```

## 1. State bucket

```bash
export REGION=europe-west1
export BUCKET=<globally-unique-name>     # e.g. <project>-tfstate

gcloud storage buckets create "gs://$BUCKET" \
  --location="$REGION" --uniform-bucket-level-access

gcloud storage buckets update "gs://$BUCKET" --versioning
```

## 2. First run

Authenticate via application-default credentials or a service-account key
(`GOOGLE_APPLICATION_CREDENTIALS` — template in `.env.example`):

```bash
gcloud auth application-default login    # or export the key file path
```

then:

```bash
task engine-check
task init-backend ENV=dev      # terragrunt init — wires the remote backend
task plan ENV=dev              # review the plan
task apply ENV=dev             # apply exactly what was reviewed
task run-all-plan ENV=dev      # once more components exist
```
