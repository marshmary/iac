# GCP provider layer (raw template)

These files are raw template layers with placeholder tokens - they are NOT
used directly. The project initializer copies `backend.tf`, `provider.tf` and
`starter.tf` from here into EVERY `envs/*/` directory (replacing the env
placeholder with each directory name) and then deletes this directory.
After init, edit the copies under `envs/<env>/`, never here.

## Required environment variables

Authentication via Application Default Credentials - set in the environment,
never commit (see `.env.example` at the repo root):

- `GOOGLE_APPLICATION_CREDENTIALS` - absolute path to a key file
- or run `gcloud auth application-default login` once

## State backend

The GCS bucket is created once per project - see `bootstrap/gcp.md` in the
repo root. One bucket, one prefix per env.
