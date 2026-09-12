# Conventions — the contract every tier obeys

These rules are identical across all four tiers. They are copied into every
generated project; agents and humans both follow them.

## Naming

- Directories: `kebab-case`. Root files: `snake_case.tf`.
- Variables/outputs/locals: `snake_case`; resources: `snake_case` with a
  semantic name (`starter`, `this`).
- Projects: kebab-case slug (`my-app`), 1–63 chars, no leading/trailing
  hyphen (cloud name limits), enforced by the init script and re-checked by
  tier variable validation where the slug is a variable.
- Azure quirk: resource names embed the prefix `rg-<project>-…` because
  resource groups dislike underscores; storage account names are lowercase
  alphanumeric only (see `docs/placeholders.md` defaults).

## Layout

- Tier 01: flat root module; envs selected by `-var-file=<env>.tfvars`.
- Tier 02: `envs/{dev,staging,prod}/` — each a full root with its own state;
  shared code in `modules/<name>/`.
- Tier 03: Terragrunt units at `envs/<env>/<component>/terragrunt.hcl`;
  shared config in `root.hcl`; modules in `modules/<name>/`.
- Tier 04: registries in `common/`; units at
  `platforms/<cloud>/envs/<env>/<component>/`; policy in `policy/`.

## State

- Remote state always; keys follow
  `<project>/[<env>/][<platform>/envs/<env>/]<component>/terraform.tfstate`
  per tier layout — one state per env root (tier 02) or per component
  (tiers 03–04).
- Terraform **workspaces are forbidden** — an environment is a directory, not
  a workspace. Directories diff well; workspaces hide drift.
- `.terraform.lock.hcl` is committed. State files never are.
- Bootstrap the backend before the first real `init` (each tier's
  `bootstrap/<cloud>.md` is a copy-paste one-pager).

## Modules (tiers 02+)

Every module has exactly: `main.tf`, `variables.tf`, `outputs.tf`,
`versions.tf`, `README.md` (with `<!-- BEGIN_TF_DOCS -->` markers for
terraform-docs injection), `examples/` usage sample, and `tests/*.tftest.hcl`
where testable. The cloud-neutral `baseline` module is the reference
implementation — copy its shape.

## Tagging

Baseline tags on everything taggable: `Project`, `Env`, `ManagedBy=iac`.
Tier 04 makes them mandatory via `policy/tags.rego` and centralizes them in
`common/tags.hcl`. Tiers 01–03 set them via `default_tags`/module locals.

## Authentication

Credentials come from the provider's standard environment variables
(`AWS_*`, `ARM_*`, `GOOGLE_*`) — never hardcoded, never in tfvars, never
committed. Each tier ships `.env.example` listing the variables per cloud;
`.env` is gitignored.

## Engine

All operations go through the tier's Taskfile (`task plan`, `task apply`, …).
The engine binary (`tofu` default, `terraform` fallback) is resolved by
`IAC_ENGINE` — see `docs/engine-duality.md`. The Taskfile auto-loads `.env`
(`dotenv: ['.env']`), so the `IAC_ENGINE` line init records takes effect
without shell exports; explicit exports still work and win.

## Verification

`task check` (fmt + backend-less init + validate, fully offline) must pass
before any change is declared done. Terragrunt tiers add `hclfmt-check` and
`hcl-validate`.
