# References — where this structure comes from

Patterns in this catalog are borrowed, not invented. Lineage recorded so
future maintainers can revisit the sources as they evolve.

| Source | What we borrowed | Lands in |
|--------|------------------|----------|
| [antonbabenko/terraform-best-practices](https://github.com/antonbabenko/terraform-best-practices) — examples grouped small → very-large | Scale-based tier boundaries: single root → multi-env state separation → shared modules + wrapper → multi-account/multi-team | tier definitions, `README.md` chooser table |
| [gruntwork-io/terragrunt-infrastructure-live-example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-example) | `root.hcl` shared config + per-unit `terragrunt.hcl` include pattern; account/region/env/category hierarchy | tiers 03–04 layout |
| [gruntwork-io/terragrunt-infrastructure-modules-example](https://github.com/gruntwork-io/terragrunt-infrastructure-modules-example) | modules repo = `modules/` + `examples/` layout | tier 02–03 module shape, tier 04 registry convention |
| create-vite / create-t3-app / create-react-app | Sibling template folders in one repo; init CLI copies + substitutes + prints next steps; templates stay plain (no generator magic) | repo layout, `scripts/init-project` |
| [AGENTS.md open standard](https://agents.md/) | "README for agents" at repo root, discovered by coding agents | root + per-tier `AGENTS.md` |
| [aws-samples/aws-terraform-best-practices](https://github.com/aws-samples/aws-terraform-best-practices) | Multi-account structure, tagging/OU conventions | tier 04 AWS platform details |
| Google Cloud Foundation Fabric / terraform-example-foundation | Env hierarchy and registry-style shared config | tier 04 `common/` registries |
| [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) | Hook ids: terraform_fmt/validate/tflint/docs, terragrunt_fmt | per-tier `.pre-commit-config.yaml` |
| OpenTofu native tests (`mock_providers`) | Offline behavioral assertions | per-tier `tests/*.tftest.hcl`, T4 of the pyramid |

Revisit cadence: whenever Terragrunt (post-1.0 "stacks") or the engines'
test frameworks shift materially, re-check the two Gruntwork repos and
re-evaluate whether tiers 03–04 should adopt the newer idioms.
