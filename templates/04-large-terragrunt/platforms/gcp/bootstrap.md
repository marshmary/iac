# platforms/gcp - bootstrap one-pager

Run ONCE per Google Cloud organization, before the first `task plan`. Creates
the GCS state bucket that `root.hcl`'s generated backend references. This
resource is deliberately NOT managed in-tree - it bootstraps the bootstrap.

## 0. Authenticate

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project __GCP_PROJECT__
```

For non-interactive environments see the Google Cloud block in `.env.example`
(`GOOGLE_APPLICATION_CREDENTIALS`; workload identity federation placeholders
for CI later - prefer it over key files).

## 1. Create the state bucket

```bash
gcloud storage buckets create gs://__STATE_BUCKET__ \
  --project=__GCP_PROJECT__ \
  --location=__REGION__ \
  --uniform-bucket-level-access

# Versioning = your undo button for state incidents
# (runbooks/state-incident.md). The GCS backend has no lock table, so this
# matters more here than on the other platforms.
gcloud storage buckets update gs://__STATE_BUCKET__ --versioning

# Keep the state bucket private
gcloud storage buckets add-iam-policy-binding gs://__STATE_BUCKET__ \
  --member="serviceAccount:<deployer-sa>@__GCP_PROJECT__.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

Notes:

- bucket names are globally unique - the `__STATE_BUCKET__` token must respect
  that;
- prefer a location matching `common/regions.hcl` `gcp_primary`;
- there is NO DynamoDB/lease equivalent for the GCS backend - versioning plus
  small team discipline is the mitigation.

## 2. First run

```bash
task engine-check
task hcl-validate PLATFORM=gcp ENV=dev COMPONENT=baseline
task plan PLATFORM=gcp ENV=dev COMPONENT=baseline
task policy-check PLATFORM=gcp ENV=dev COMPONENT=baseline
task apply PLATFORM=gcp ENV=dev COMPONENT=baseline
```

The first `plan` writes the initial state object
`envs/dev/baseline/terraform.tfstate` into the bucket - no pre-seeding needed;
keys inherit the `envs/<env>/<component>` pattern automatically.

## CI note (for later)

When you wire CI, authenticate via workload identity federation on the runner
service account (no key files in the pipeline). Permissions floor: Storage
Object Admin on the state bucket only, scoped to the deployer service account.
