# Runbook - adding an environment (e.g. `staging`)

Works identically on every platform. Time: ~15 minutes plus bootstrap.

## 1. Copy the envs subtree, per platform

Copy an existing env directory and edit its `env.hcl`:

```sh
cp -r platforms/aws/envs/dev platforms/aws/envs/staging
cp -r platforms/azure/envs/dev platforms/azure/envs/staging
cp -r platforms/gcp/envs/dev platforms/gcp/envs/staging
```

Then in each `platforms/<cloud>/envs/staging/env.hcl` set:

```hcl
locals {
  env  = "staging"
  tier = "nonprod"   # or "prod" if this env is production-grade
}
```

The directory name and `locals.env` MUST match the registry key added in
step 2 - `root.hcl` indexes the registries by this name.

## 2. Update the registries in common/

`common/accounts.hcl` - add the key to every cloud map you just copied a
subtree for:

```hcl
aws_accounts = {
  dev     = "111111111111"
  staging = "222222222222"   # <- new
  prod    = "333333333333"
}
```

Same for `azure_subscriptions` and `gcp_projects`. If the new env deploys to a
different region, add that to `common/regions.hcl` and read it in the
platform's `root.hcl` (see the comments there).

Nothing else reads hardcoded environment lists - except `policy/naming.rego`'s
`environments` set, which must gain `"staging"` so the naming gate keeps
matching. (Documented sync rule in that file.)

## 3. Backend keys - nothing to do

This is the point of the design: state keys derive from
`path_relative_to_include()`, so `platforms/aws/envs/staging/baseline`
automatically gets key `envs/staging/baseline/terraform.tfstate` in the
existing per-platform backend. No new bucket, no new container, no key
pre-seeding. The first `task plan` creates the key.

If the new env uses a DIFFERENT cloud account you still do nothing in-tree -
the account comes from the registry (step 2). Only a brand-new state backend
would need the platform's `bootstrap.md` re-run.

## 4. Policy - unchanged

`policy/tags.rego` reads tags from the plan document; `policy/naming.rego`
validates names against the env token you just registered. No policy edits
beyond the `environments` sync in step 2.

## 5. Verify

```sh
task check                       # format + validate across all platforms
task plan PLATFORM=aws ENV=staging COMPONENT=baseline
task policy-check PLATFORM=aws ENV=staging COMPONENT=baseline
task apply PLATFORM=aws ENV=staging COMPONENT=baseline
```

Repeat plan/apply per platform. Open the PR with all platforms' changes in it
so reviewers see the environment landing as one unit.
