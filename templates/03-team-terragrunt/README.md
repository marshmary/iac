# 03 — Team Terragrunt

Tier 03 of the IaC template catalog: the DRY multi-environment layout for
teams of roughly 5–20 people, built on Terragrunt with the Gruntwork
include pattern (in the style of `terragrunt-infrastructure-live-example`).
One shared `root.hcl` holds everything common; each component per
environment is a tiny `terragrunt.hcl` unit; reusable modules live under
`modules/`.

Multi-cloud by construction: `scripts/init-project` injects the chosen
provider's backend and provider `generate` blocks into `root.hcl` between
the `CLOUD PROVIDER` markers and deletes `providers/` at creation time.

Engine duality: everything runs on OpenTofu or Terraform — the Taskfile
resolves whichever binary is installed (`IAC_ENGINE` selects the
preference, default `tofu`) and hands it to Terragrunt via `--tf-path`.
Nothing in this repo hardcodes one engine.

## Layout

```text
.
├── AGENTS.md                  # machine-facing guide (for humans and AI agents)
├── README.md                  # this file
├── Taskfile.yml               # task runner: engine-aware plan/apply/check
├── root.hcl                   # shared Terragrunt config + injected cloud block
├── .pre-commit-config.yaml    # fmt / validate / tflint / docs hooks
├── .tflint.hcl                # tflint config (core terraform plugin only)
├── .terraform-version         # 1.9.0 — tfenv/tenv pin
├── .opentofu-version          # 1.9.0 — tofu pin
├── .terragrunt-version        # 0.72.6 — tgenv pin
├── .env.example               # credentials template (never commit .env)
├── envs/
│   ├── dev/
│   │   ├── env.hcl            # dev-level locals (tier, flags)
│   │   └── baseline/
│   │       └── terragrunt.hcl # dev/baseline unit: include + source + inputs
│   └── prod/
│       ├── env.hcl
│       └── baseline/terragrunt.hcl
├── modules/
│   └── baseline/              # convention module (provider-free)
│       ├── main.tf            # name_prefix + tags + terraform_data
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf        # engine version constraint only
│       ├── examples/basic/    # minimal usage example
│       └── tests/             # native .tftest.hcl suite
└── bootstrap/
    ├── aws.md                 # create the S3 + DynamoDB state backend
    ├── azure.md               # create the RG + storage + container backend
    └── gcp.md                 # create the versioned GCS bucket backend
```

The raw template also shipped a `providers/` directory; init-project
injected your chosen cloud into `root.hcl` and removed it.

## Quickstart

1. Bootstrap the shared state backend for your cloud (one-time):
   `bootstrap/aws.md` or `bootstrap/azure.md` or `bootstrap/gcp.md`.
   The values you create land in the injected backend block in `root.hcl`.
2. `task engine-check` — verify an engine binary and terragrunt are on PATH.
3. `task hcl-validate` — parse-check the Terragrunt configuration offline.
4. `task init-backend ENV=dev` — wire the remote state backend for the unit.
5. `task plan ENV=dev` — review the plan (written to `tfplan`).
6. `task apply ENV=dev` — apply exactly what you reviewed.
7. When more components exist: `task run-all-plan ENV=dev`, read every
   unit's plan end to end, and only then `task run-all-apply ENV=dev`.

Target a different component with `COMPONENT=<name>` (default `baseline`)
and a different environment with `ENV=<name>` (default `dev`).

## Testing without a cloud

`task check` runs fully offline: Terragrunt HCL format check plus
`hcl validate`, then module `fmt -check`, `init -backend=false` and
`validate`. The `baseline` component also plans offline — the injected
provider block ships commented out precisely so convention-only units
need no credentials. Module tests: `task test` (native test framework,
guarded to the tofu engine).

## Terragrunt notes

- Version pins: `.terragrunt-version` (read by tgenv; pinned to 0.72.6),
  `.terraform-version` and `.opentofu-version` (both 1.9.0, read by
  tfenv/tenv).
- The `generate` blocks injected into `root.hcl` write `backend.tf` and
  `provider.tf` into each unit's `.terragrunt-cache` working directory at
  runtime — nothing generated is ever committed.
- State keys mirror the tree — `envs/<env>/<component>/terraform.tfstate`
  — because the backend `key` (GCS: `prefix`) uses
  `path_relative_to_include()`.
- `terraform { source = "<repo-root>//modules/<name>" }` — Terragrunt
  copies the tree before the `//` into the unit's cache and runs the
  module found after it.
- `task graph ENV=dev` renders the dependency DAG (`deps.dot`, or
  `deps.png` when Graphviz is installed).

## Windows

Task and Terragrunt run natively, but the pre-commit hooks and the
bootstrap snippets assume a POSIX shell — run them from Git Bash or WSL.
`pre-commit` does not support cmd/PowerShell hosts.

## Growing

- New component or environment: see the "How to grow" section of
  `AGENTS.md`.
- When this layout stops fitting the team, graduate to the next tier —
  see `docs/migrations/03-to-04.md` (ships with the catalog's migration
  flow, not this template).
