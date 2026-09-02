# platforms/aws

AWS subtree of the tier-04 multi-cloud live repository.

## How this tree relates to `common/`

This subtree owns NO registries. It reads them:

| Value | Source | Read in |
| --- | --- | --- |
| account ID per env | `common/accounts.hcl` (`aws_accounts`) | `root.hcl` (locals) |
| region | `common/regions.hcl` (`aws_primary`) | `root.hcl` (locals) |
| mandatory tags | `common/tags.hcl` (`mandatory_tags`) | `root.hcl` (locals) |
| env / tier | `envs/<env>/env.hcl` | `root.hcl` (locals) |

`root.hcl` merges those into `common_tags` and generates the S3 backend plus a
commented provider block for every component below it. Components never
duplicate any of this - they read `include.root.locals.*`.

## State key scheme

Each component's state lives at:

```
<platform>/envs/<env>/<component>/terraform.tfstate
```

Concretely for this subtree: the per-platform bucket (see `bootstrap.md`) holds
key `envs/<env>/<component>/terraform.tfstate`, because `root.hcl` generates
`key = "${path_relative_to_include()}/terraform.tfstate"`. The bucket is
dedicated to AWS state, so the full logical address - bucket + key - is exactly
the scheme above.

## Layout

```
platforms/aws/
├── root.hcl          # shared locals + generated backend/provider
├── bootstrap.md      # one-pager: create the state bucket + lock table, first run
└── envs/
    ├── dev/
    │   ├── env.hcl               # env = "dev", tier = "nonprod"
    │   └── baseline/terragrunt.hcl
    └── prod/
        ├── env.hcl               # env = "prod", tier = "prod"
        └── baseline/terragrunt.hcl
```

Start with `bootstrap.md`, then `task plan PLATFORM=aws ENV=dev` from the repo
root. New environments: `runbooks/adding-an-environment.md`.
