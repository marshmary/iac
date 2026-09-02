# Policy as code (OPA / conftest)

Gates that run against a rendered plan JSON, before anything is applied.

## What conftest runs

From the repo root, after a plan exists:

```sh
task plan PLATFORM=aws ENV=dev COMPONENT=baseline
task policy-check PLATFORM=aws ENV=dev COMPONENT=baseline
```

`policy-check` is exactly:

```sh
<engine> show -json <component>/tfplan > <component>/tfplan.json
conftest test <component>/tfplan.json -p policy/
```

Semantics:

- `deny` = **gate** - a single deny failure means the component is not
  applyable under house rules. `task apply` is not blocked mechanically by
  conftest; it is blocked by convention (see AGENTS.md safety rules) and by CI
  once CI lands.
- `warn` = **advise** - surfaces hygiene issues without blocking. None of the
  shipped rules warn yet; the distinction exists so extensions have a place
  to be soft.

## Shipped rules

| File | Enforces | Source of truth |
| --- | --- | --- |
| `tags.rego` | every planned resource that HAS a tag map (AWS `tags`, Azure `tags`, GCP `labels`) carries all mandatory tag keys | `common/tags.hcl` (`mandatory_tags`) |
| `naming.rego` | sample named resources (`aws_s3_bucket`, `azurerm_resource_group`, `google_storage_bucket`) contain the project and env tokens in their names | `__PROJECT_NAME__` substitution + `platforms/*/envs/*` |

Pragmatic scope, on purpose: resources without a `tags`/`labels` attribute
pass `tags.rego` (no tag support = nothing to check); `naming.rego` checks a
deliberately tiny, commented list so failures stay actionable. Tighten both as
the catalog grows - not before.

Sync rule: `tags.rego`'s `mandatory_tags` set MUST mirror
`common/tags.hcl`'s `locals.mandatory_tags`. Change them in the same commit.

## How to extend

1. Write a new rule in `policy/<topic>.rego`, package `terraform.plan`, using
   `deny contains msg if { ... }` (the future-keyword bridge imports at the
   top of each file keep it valid on both recent OPA v0.x and v1.x).
2. Read the plan document via `input` - useful anchors:
   `input.resource_changes[_].{address,type,change.after}`,
   `input.planned_values.root_module.resources`,
   `input.configuration.root_module`.
3. Emit actionable messages: resource address + what is wrong + which file
   defines the rule.
4. Test locally against a real plan:

   ```sh
   task plan PLATFORM=aws ENV=dev COMPONENT=baseline
   task policy-check PLATFORM=aws ENV=dev COMPONENT=baseline
   ```

   (or feed any saved plan JSON straight to `conftest test -p policy/`).

## Wire-in points

- `task policy-check` - the developer gate; run it between `task plan` and
  `task apply`.
- pre-commit - intentionally NOT hooked (conftest needs a rendered plan,
  which pre-commit cannot produce). The `.pre-commit-config.yaml` comment
  block documents `task policy-check` as the gate.
- CI (future) - run the same task on every PR and before every apply; a deny
  fails the pipeline.
