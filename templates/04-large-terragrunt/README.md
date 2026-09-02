# Tier 04 - Large multi-team Terragrunt repository

Multi-account, multi-region, multi-cloud live repository built on Terragrunt,
policy-as-code (OPA/conftest) and runbooks. This is the top tier of the
template catalog: it assumes MANY teams share one IaC repo, deploy into
separate accounts/subscriptions/projects per environment, and keep all three
major clouds side by side. Hierarchy inspiration: Gruntwork's
account/region/env/component live layout, aws-samples terraform best
practices, and Google Cloud Foundation Fabric.

Engine duality: runs on OpenTofu or Terraform - tasks resolve the binary, and
docs never hardcode one (`task engine-check` shows what you have).

## Layout

```
.
├── AGENTS.md               # operating manual - start here after this README
├── Taskfile.yml            # the PLATFORM/ENV/COMPONENT task matrix
├── common/                 # cross-cloud registries - single source of truth
│   ├── accounts.hcl        #   env -> AWS account / Azure subscription / GCP project
│   ├── regions.hcl         #   primary region per cloud
│   └── tags.hcl            #   mandatory tag policy (enforced by policy/tags.rego)
├── platforms/              # one subtree per cloud - keep ALL of them
│   ├── aws/                #   root.hcl + bootstrap.md + envs/<env>/<component>
│   ├── azure/
│   └── gcp/
├── policy/                 # OPA/conftest gates: tags.rego, naming.rego
├── runbooks/               # drift, adding-an-environment, state-incident
├── .pre-commit-config.yaml # terragrunt_fmt etc. (+ policy gate documentation)
├── .tflint.hcl             # strict tier-4 ruleset (comment headers, unused decls)
└── .env.example            # credential template - never commit the real one
```

Deploy units are `platforms/<cloud>/envs/<env>/<component>/terragrunt.hcl`;
the path doubles as the state key scheme
`<platform>/envs/<env>/<component>/terraform.tfstate`.

## Quickstart

1. Pick your platform and bootstrap its state backend once:
   `platforms/aws/bootstrap.md` (or azure / gcp).
2. `task engine-check` - confirm terragrunt + engine (+ note on conftest).
3. `task hcl-validate PLATFORM=aws ENV=dev COMPONENT=baseline` - needs a real
   module source first: point `terraform.source` at your registry or the
   local escape hatch (next section).
4. `task plan PLATFORM=aws ENV=dev COMPONENT=baseline` - writes `tfplan`
   next to the component.
5. Read the plan. Really read it.
6. `task policy-check PLATFORM=aws ENV=dev COMPONENT=baseline` - conftest
   gate over the plan.
7. `task apply PLATFORM=aws ENV=dev COMPONENT=baseline`.

Repeat per platform/env with the same task names - only the variables change.

## Module registry convention (docs placeholder)

Modules are NOT vendored in this repository. They live in a separate module
registry repo, referenced by every component's `terraform.source`:

```
git::https://github.com/__PROJECT_NAME__/iac-modules.git//baseline?ref=v0.0.0
```

- That URL is a PLACEHOLDER - replace `__PROJECT_NAME__/iac-modules` with
  your registry location before your first plan (a BIG header comment in each
  component repeats this).
- Pin every module to a tag: `?ref=vX.Y.Z`, never a branch. Bump pins via PR
  so module changes are reviewed like any other code change.
- Local escape hatch: if you choose to vendor modules instead, each component
  header documents the pattern
  `source = "${find_in_parent_folders("root.hcl")}/../../../modules-local/baseline"`,
  which resolves to `<repo-root>/modules-local/baseline`.
- `docs/conventions.md` (copied in by init) will carry the long-form version
  of this convention; this section is the placeholder note until then.

## Policy as code

`policy/` holds OPA/conftest rules evaluated against a rendered plan:

- `tags.rego` - every planned resource that HAS a tag map (AWS `tags`, Azure
  `tags`, GCP `labels`) must carry the mandatory keys defined in
  `common/tags.hcl`; resources without tag support pass.
- `naming.rego` - sample named resources must contain the project and env
  tokens (`<project>-<env>-<name>`).

`deny` is a gate (do not apply), `warn` would be advice. Wire-in points and
extension guide: `policy/README.md`. The developer flow is always
`task plan` -> `task policy-check` -> `task apply`.

## Testing without a cloud

- `task check` runs fully offline: the HCL format gate plus validation of the
  dev baseline across all three platforms. (Validation still needs the module
  source to resolve and the state backend to exist - bootstrap first; it
  contacts no cloud resource APIs.)
- The generated provider blocks in each `root.hcl` are COMMENTED OUT so
  provider-free components (the baseline) plan without any cloud credentials
  and without provider downloads. Uncomment per component when real
  resources land.
- `task policy-check` runs conftest locally against a saved `tfplan.json` -
  no cloud access needed beyond the plan itself.
- Until modules exist in a registry, even plan-level testing can point at
  `modules-local/` via the escape hatch above.

## Runbooks index

| Runbook | When |
| --- | --- |
| `runbooks/drift-remediation.md` | a plan shows changes nobody asked for |
| `runbooks/adding-an-environment.md` | new env (e.g. staging) across platforms |
| `runbooks/state-incident.md` | stuck lock, imports, corrupted state |

## Windows notes

- Use Git Bash (or WSL) as your shell: the tasks are POSIX `sh`, and
  pre-commit needs a POSIX shell on Windows anyway.
- No symlinks anywhere in this template - it is Windows-safe by construction.
- `task` (go-task), `terragrunt`, the engine and `conftest` must be on PATH;
  `task engine-check` tells you what resolved.

## Graduating beyond this tier

This is the top tier of the catalog. When ONE repo no longer fits - typically
when platform teams block each other in review queues or the run-all blast
radius gets uncomfortable - split per-platform repositories (aws / azure / gcp
each get their own live repo + shared registry), keeping `common/` registries
either replicated or lifted into a small config repo. The docs/ directory
(copied in by init) is the designated home for that migration guide; until
then, this repo is the whole org.
