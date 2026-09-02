# Testing without a cloud account

The catalog must prove generated projects are correct **before** anyone has
cloud credentials. `tests/run-all.sh` instantiates every tier × provider ×
engine into a scratch directory and runs the pyramid below; every level is
skipped gracefully (and reported as `SKIP`) when its CLIs are absent.
Level T0 runs with nothing but a POSIX shell installed.

| Level | Check | Needs | Proves |
|-------|-------|-------|--------|
| T0 | golden-manifest tree compare (init → `find \| sort` vs `tests/manifests/`) + zero surviving tokens | shell only | init script, merge rules, substitution |
| T1 | `fmt -check -recursive`, `tflint`, `terragrunt hcl fmt --check` | CLIs, no creds | syntax, lint |
| T2 | `init -backend=false` + `validate` on every root/unit | CLIs + registry access | configs parse, provider schemas resolve, wiring consistent |
| T3 | offline plan: `plan -refresh=false -var dry_run=true` with fake creds (`tests/fixtures/*.env`) | CLIs, no cloud | variables/type constraints, starter resources plan |
| T4 | `tofu test` with native tests (mock-free where possible) | `tofu` | behavioral assertions on modules |
| T5 | `tofu show -json tfplan \| conftest test -p policy/` | `conftest` | plans obey tag/naming policy |
| T6 | LocalStack / Azurite real apply via `docker compose -f tests/docker-compose.emulators.yml` | Docker | full lifecycle, opt-in only |

Provider caveats: T3 is guaranteed on AWS for tiers 01–02 (the provider ships
`skip_* = var.dry_run` flags); Azure/GCP providers phone home while
configuring, so their T3 runs report SKIP-with-reason unless an emulator (T6)
is up. Terragrunt tiers skip T3 because unit plans initialize the real state
backend first — their offline coverage is T2 module-level validate plus the
provider-free `baseline` module's native tests (T4).

## Running

```sh
tests/run-all.sh                  # full matrix, auto-detects tools
TIERS="01 03" tests/run-all.sh    # subset
tests/gen-manifests.sh            # regenerate golden trees after deliberate structure change
```

PowerShell users: `tests/run-all.ps1` mirrors T0–T2.

## Full matrix in a container (zero host installs)

```sh
tests/run-in-docker.sh                       # builds the pinned runner image, runs the whole matrix
tests/run-in-docker.sh tofu fmt -check -recursive templates/01-solo   # ad-hoc command, pinned toolchain
```

`tests/docker/Dockerfile.runner` bundles tofu, terraform, terragrunt,
tflint, go-task and conftest at the exact versions the templates declare
(same as the version-pin files) — one image, no version skew, no host
installs; docker or podman is auto-detected. Official per-tool images exist
(`hashicorp/terraform` on Docker Hub, `ghcr.io/opentofu/opentofu`) but
OpenTofu's image is deprecated for direct use, and a single runner image is
what makes T1–T5 run in one shot. This is the recommended gate before any
change to templates or scripts.

## Inside a generated project

`task check` = T1 fmt + T2 backend-less init/validate (+ Terragrunt hcl
checks) — fully offline, run it constantly. `task plan-dry` = T3.
Tier AGENTS.md instructs coding agents to run `task check` before claiming
work is done; a future CI pipeline calls the identical tasks.

## Installing the CLIs (optional, for the full matrix)

tofu (`tenv` or the OpenTofu installer), terraform, terragrunt (tgenv),
tflint, go-task, conftest — all single binaries; `tenv` can manage tofu,
terraform, and terragrunt pins together and reads this repo's version files.
