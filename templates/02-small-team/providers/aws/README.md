# AWS provider layer (raw template)

These files are raw template layers with placeholder tokens - they are NOT
used directly. The project initializer copies `backend.tf`, `provider.tf` and
`starter.tf` from here into EVERY `envs/*/` directory (replacing the env
placeholder with each directory name) and then deletes this directory.
After init, edit the copies under `envs/<env>/`, never here.

## Required environment variables

Credentials come from the environment (never commit them - copy
`.env.example` to `.env`, which is gitignored):

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (SSO / temporary credentials)

Any standard AWS credential chain (SSO, shared config/profile) also works.

## State backend

The S3 bucket is created once per project - see `bootstrap/aws.md` in the
repo root. One bucket, one key per env, S3-native locking (`use_lockfile`).
