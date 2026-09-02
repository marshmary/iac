# Google Cloud provider addendum

These files are merged into the project root when the template is
instantiated with `-Provider gcp`: `backend.tf` (GCS state), `provider.tf`
(google 6.x, project + region) and `starter.tf` (example storage bucket).

Auth via Application Default Credentials: `gcloud auth application-default
login`, or `GOOGLE_APPLICATION_CREDENTIALS` pointing at a service-account
key file — see `.env.example`.

Create the state bucket and enable APIs first: `bootstrap/gcp.md`.
