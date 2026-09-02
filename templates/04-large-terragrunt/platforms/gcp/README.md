# platforms/gcp

Google Cloud subtree of the tier-04 multi-cloud live repository.

## How this tree relates to `common/`

This subtree owns NO registries. It reads them:

| Value | Source | Read in |
| --- | --- | --- |
| project per env | `common/accounts.hcl` (`gcp_projects`) | `root.hcl` (locals) |
| region | `common/regions.hcl` (`gcp_primary`) | `root.hcl` (locals) |
| mandatory tags | `common/tags.hcl` (`mandatory_tags`) | `root.hcl` (locals) |
| env / tier | `envs/<env>/env.hcl` | `root.hcl` (locals) |

`root.hcl` merges those into `common_tags` (GCP resources receive them via
their `labels` maps) and generates the GCS backend plus a commented provider
block for every component below it. Components never duplicate any of this -
they read `include.root.locals.*`.

## State key scheme

Each component's state lives at:

```
<platform>/envs/<env>/<component>/terraform.tfstate
```

Concretely for this subtree: the per-platform bucket (see `bootstrap.md`)
holds object `envs/<env>/<component>/terraform.tfstate`, because `root.hcl`
generates `prefix = "${path_relative_to_include()}"`. The bucket is dedicated
to GCP state, so the full logical address - bucket + prefix - is exactly the
scheme above.

## Layout

```
platforms/gcp/
├── root.hcl          # shared locals + generated backend/provider
├── bootstrap.md      # one-pager: create the state bucket, first run
└── envs/
    ├── dev/
    │   ├── env.hcl               # env = "dev", tier = "nonprod"
    │   └── baseline/terragrunt.hcl
    └── prod/
        ├── env.hcl               # env = "prod", tier = "prod"
        └── baseline/terragrunt.hcl
```

Start with `bootstrap.md`, then `task plan PLATFORM=gcp ENV=dev` from the repo
root. New environments: `runbooks/adding-an-environment.md`.

Note: the GCS backend has NO lock table equivalent - GCS object versioning
(see `bootstrap.md`) is the safety net; conflicts are rare but resolved via
`runbooks/state-incident.md`.
