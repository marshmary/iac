# AWS provider addendum

These files are merged into the project root when the template is
instantiated with `-Provider aws`: `backend.tf` (S3 + DynamoDB state/lock),
`provider.tf` (AWS provider, default tags, dry_run skip flags) and
`starter.tf` (example bucket).

Credentials come from the standard AWS chain (`AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, profile or SSO) — see `.env.example`.

Create the state bucket and lock table first: `bootstrap/aws.md`.
