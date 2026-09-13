# Testing without a cloud account

The catalog must prove generated projects are correct **before** anyone has
cloud credentials. `tests/run-all.sh` instantiates every tier × provider ×
engine into a scratch directory and runs the pyramid below; every level is
skipped gracefully (and reported as `SKIP`) when its CLIs are absent.
Level T0 runs with nothing but a POSIX shell installed.

| Level | Check | Needs | Proves |
|-------|-------|-------|--------|
| T0 | golden-manifest tree compare (init → `find \| sort` vs `tests/manifests/`) + zero surviving tokens + pin consistency (`tests/check-pins.{sh,ps1}`) + bootstrap parity/tamper gate | shell only | init script, merge rules, substitution, atomic engine pins, thin one-liner entry |
| T1 | `fmt -check -recursive`, `tflint`, `checkov` (security; tier `.checkov.yaml` carries documented suppressions), `terragrunt hcl fmt --check` | CLIs, no creds | syntax, lint, security baseline |
| T2 | `init -backend=false` + `validate` on every root/unit | CLIs + registry access | configs parse, provider schemas resolve, wiring consistent |
| T3 | offline plan: `plan -refresh=false -var dry_run=true` with fake creds (`tests/fixtures/*.env`) | CLIs, no cloud | variables/type constraints, starter resources plan |
| T4 | `tofu test` with native tests (mock-free where possible) | `tofu` | behavioral assertions on modules |
| T5 | `conftest verify` policy unit tests + `tofu show -json tfplan \| conftest test -p policy/` | `conftest` | rules behave as documented; plans obey tag/naming policy |
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

PowerShell users: `tests/run-all.ps1` mirrors T0–T2 (pin gate, init,
case-sensitive manifest compare, `task --list`, and per-engine fmt-check +
init/validate for every engine on PATH). tflint, the terragrunt hcl checks
and T3–T6 remain bash-runner territory; run those through
`tests/run-in-docker.sh`.

## Bootstrap gate

T0 also gates the one-liner entry point (`scripts/bootstrap.{sh,ps1}`,
`docs/adr/0001-one-liner-installer.md`): instantiating through the bootstrap
with a local tarball source and a local directory source must produce trees
identical to a direct `init-project` run, and a corrupted tarball must be
rejected on sha256 mismatch. The gate runs fully offline via `--source`
(bootstrap flag), so it needs no published release and no network — the
remote path (latest-release resolve + `checksums.txt` fetch) is exercised by
the manual smoke test in `docs/release-process.md` at release time. Its
purpose is mechanical enforcement of "the bootstrap stays thin": any template
logic sneaking into the installer shows up as a tree mismatch or a failed
parity line.

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

### Policy tooling pins

The runner image is the only place tool versions are pinned for policy work
(`ARG TFLINT_VERSION`, `ARG CONFTEST_VERSION` in
`tests/docker/Dockerfile.runner`); the engine/terragrunt pins come from the
tiers' version files. Generated projects do NOT pin these CLIs themselves —
treat the runner versions as the reference matrix. Two caveats:

- tflint plugins (the `terraform` ruleset in each tier's `.tflint.hcl`) have
  no version constraint, so `tflint --init` fetches the latest compatible
  plugin — rule output can drift independently of the pinned binary. Pin
  `version` in the plugin block if a project needs reproducible lint output.
- conftest/OPA: the tier 04 policies use only stable Rego with
  `future.keywords` bridge imports; verify upgrades with `conftest verify`
  once policy tests land.

## Inside a generated project

`task check` = T1 fmt + T2 backend-less init/validate (+ Terragrunt hcl
checks) — fully offline, run it constantly. `task plan-dry` = T3.
Tier AGENTS.md instructs coding agents to run `task check` before claiming
work is done; a future CI pipeline calls the identical tasks.

## Installing the CLIs (optional, for the full matrix)

tofu (`tenv` or the OpenTofu installer), terraform, terragrunt (tgenv),
tflint, go-task, conftest, checkov (pip) — all single binaries except the
last; `tenv` can manage tofu, terraform, and terragrunt pins together and
reads this repo's version files.
