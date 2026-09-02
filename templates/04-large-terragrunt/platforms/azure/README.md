# platforms/azure

Azure subtree of the tier-04 multi-cloud live repository.

## How this tree relates to `common/`

This subtree owns NO registries. It reads them:

| Value | Source | Read in |
| --- | --- | --- |
| subscription per env | `common/accounts.hcl` (`azure_subscriptions`) | `root.hcl` (locals) |
| location | `common/regions.hcl` (`azure_primary`) | `root.hcl` (locals) |
| mandatory tags | `common/tags.hcl` (`mandatory_tags`) | `root.hcl` (locals) |
| env / tier | `envs/<env>/env.hcl` | `root.hcl` (locals) |

`root.hcl` merges those into `common_tags` and generates the azurerm backend
plus a commented provider block for every component below it. Components never
duplicate any of this - they read `include.root.locals.*`.

## State key scheme

Each component's state lives at:

```
<platform>/envs/<env>/<component>/terraform.tfstate
```

Concretely for this subtree: the per-platform storage account container (see
`bootstrap.md`) holds key `envs/<env>/<component>/terraform.tfstate`, because
`root.hcl` generates `key = "${path_relative_to_include()}/terraform.tfstate"`.
The storage account is dedicated to Azure state, so the full logical address -
account/container + key - is exactly the scheme above.

## Layout

```
platforms/azure/
├── root.hcl          # shared locals + generated backend/provider
├── bootstrap.md      # one-pager: create the state RG/storage/container, first run
└── envs/
    ├── dev/
    │   ├── env.hcl               # env = "dev", tier = "nonprod"
    │   └── baseline/terragrunt.hcl
    └── prod/
        ├── env.hcl               # env = "prod", tier = "prod"
        └── baseline/terragrunt.hcl
```

Start with `bootstrap.md`, then `task plan PLATFORM=azure ENV=dev` from the
repo root. New environments: `runbooks/adding-an-environment.md`.
