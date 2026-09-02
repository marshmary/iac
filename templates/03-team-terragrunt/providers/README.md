# providers/ — the injection contract

This directory is the multi-cloud switch of the tier-03 template. It exists
only in the raw template: `scripts/init-project.{sh,ps1}
-Tier 03 -Provider <cloud> -Name <project>` does the following at
instantiation time:

1. Copies the whole template folder.
2. Reads `providers/<cloud>/root-provider.hcl`.
3. Replaces the content between the two `CLOUD PROVIDER` marker lines in
   `root.hcl` with that file's contents (the marker lines themselves are
   kept so the region stays addressable).
4. Substitutes the placeholder tokens globally (`__PROJECT_NAME__`,
   `__REGION__`, `__STATE_BUCKET__`,
   `__STATE_RESOURCE_GROUP__`, `__STATE_STORAGE_ACCOUNT__`,
   `__STATE_CONTAINER__`, `__GCP_PROJECT__` — only the ones the chosen
   cloud actually uses).
5. Deletes `providers/` and git-inits the result.

## What a root-provider.hcl contains

Two Terragrunt `generate` blocks, inherited by every unit through
`include "root"` in each `terragrunt.hcl`:

- `generate "backend"` — writes `backend.tf` into each unit's
  `.terragrunt-cache` working directory at runtime, pointing at the shared
  state backend created via `bootstrap/<cloud>.md`. The state `key` (or
  `prefix` on GCS) uses `path_relative_to_include()`, so every unit gets
  its own state file: `envs/<env>/<component>/terraform.tfstate`.
- `generate "provider"` — writes `provider.tf`, deliberately kept as a
  commented block so provider-free components such as `baseline` plan
  fully offline. Uncomment it (or copy it) in components that manage real
  cloud resources.

## Switching clouds after init

The markers survive init, so the injected region can be replaced by hand:

1. Reconstruct the payload of `providers/<new-cloud>/root-provider.hcl`
   (this README plus the template catalog's git history are the record of
   what each file contained).
2. Replace everything between the two marker lines in `root.hcl` with it.
3. Fill in the token values by hand — init-time substitution no longer
   applies.
4. Run `task init-backend ENV=<env> COMPONENT=<component>` for each unit
   to re-generate and re-init backends. Note that existing state still
   lives in the old backend; migrating state between backends is a
   separate, deliberate exercise and is out of scope here.
