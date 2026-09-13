# iac — a multi-scale Terraform / OpenTofu / Terragrunt template catalog

One repo, four ready-to-instantiate project skeletons. Pick the tier that matches your
team size today; graduate to the next tier when it hurts (see `docs/migrations/`).
Every tier is **multi-cloud** (AWS / Azure / GCP), **engine-agnostic**
(`tofu` or `terraform`, switched by one env var), and ships a **local-only
workflow** — Taskfile tasks + pre-commit hooks, no CI required.

> Packaging model borrowed from `create-vite` / `create-t3-app`: sibling
> template folders in one repo + a tiny init script. Scale-tier model inspired
> by antonbabenko/terraform-best-practices. See `docs/references.md`.

## Tier catalog

| Tier | Folder | Engine | Built for | Move up when… |
|------|--------|--------|-----------|---------------|
| 01 | `templates/01-solo/` | plain TF/TOFU | one person, 1–2 envs, single root | you need per-env roots + shared modules |
| 02 | `templates/02-small-team/` | plain TF/TOFU | 2–8 people, dev/staging/prod, `modules/` | copy-paste between env roots becomes painful |
| 03 | `templates/03-team-terragrunt/` | Terragrunt | 5–20 people, DRY multi-env/multi-region | multi-account / multi-cloud / policy gates |
| 04 | `templates/04-large-terragrunt/` | Terragrunt + OPA | multi-team, multi-account, multi-cloud | you split per-platform repos |

## Quickstart — one command, no clone

Git Bash / WSL / macOS / Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.sh | bash -s -- -t 01 -p aws -n my-app -d ../my-app
```

PowerShell 5.1+ (Windows PowerShell or pwsh):

```powershell
Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.ps1) } -Tier 01 -Provider aws -Name my-app -Dest ..\my-app"
```

> **PowerShell users:** do not paste the `curl …` line into PowerShell —
> there `curl` is an alias for `Invoke-WebRequest` and the pipe will not do
> what you want. Use the `Invoke-Expression` form above; `curl | bash` is
> for Git Bash / WSL / macOS / Linux shells only.

Leave off the trailing arguments to be prompted one by one
(tier → provider → engine → name → destination) — the same interactive
chooser the init scripts have always had.

What happens: the installer downloads the latest **published release** of
this catalog, verifies the tarball's sha256 against that release's
`checksums.txt`, and runs the same tested `scripts/init-project.{sh,ps1}`
a clone would. Design and rejected alternatives:
`docs/adr/0001-one-liner-installer.md`; release/versioning rules:
`docs/release-process.md`.

Bootstrap flags: `--ref <tag|branch|sha>` (`-Ref`, default: latest release),
`--sha256 <hex>`, `--source <dir|tar.gz>` (offline/testing), `--keep`;
everything else is forwarded to the init script.

> **Until the first release is published** the default mode has nothing to
> resolve — add `--ref main` (bash) / `-Ref main` (PowerShell) to the
> one-liners. This note is removed at `v0.1.0`.

### Fallback — clone the catalog

For offline use, or environments that forbid pipe-to-shell:

```sh
git clone https://github.com/marshmary/iac.git && cd iac
scripts/init-project.sh -t 01 -p aws -n my-app -d ../my-app
scripts/init-project.sh -t 03 -p azure -e terraform -n billing-infra -d ../billing-infra
```

PowerShell: `scripts/init-project.ps1 -Tier 01 -Provider aws -Name my-app -Dest ..\my-app`

Init flags (forwarded verbatim by the one-liners; also used directly):
`-t/--tier` (01–04), `-p/--provider` (aws/azure/gcp; ignored for tier 04,
which keeps all platforms), `-e/--engine` (tofu default / terraform),
`-n/--name` (kebab-case slug), `-d/--dest`, `--region` (override default),
`--no-git`, `--ci <github|gitlab|none>` (opt-in pipeline skeleton; default
`none` ships no CI, staying local-first).

The init script copies the tier, merges the chosen cloud's `providers/` layer,
substitutes every `__TOKEN__`, copies shared docs into the new project, runs
`git init`, and prints next steps. It **fails loudly if any token survives** —
that is a built-in self-test.

## Proving generated projects work — without a cloud account

`tests/run-all.sh` instantiates every tier × provider × engine into a scratch
dir and runs a dependency-graded pyramid:

| Level | Check | Needs |
|-------|-------|-------|
| T0 | golden-manifest tree compare + zero leftover tokens | nothing (always runs) |
| T1 | `fmt -check` + `tflint` + `terragrunt hcl fmt` | CLIs, no creds |
| T2 | `init -backend=false` + `validate` | CLIs + registry access |
| T3 | offline `plan -refresh=false` with fake creds | CLIs, no cloud |
| T4 | OpenTofu native tests (`mock_providers`) | `tofu` |
| T5 | `conftest` policy assertions on plan JSON | `conftest` |
| T6 | LocalStack / Azurite full apply (opt-in) | Docker |

Details: `docs/testing.md`. The generated project itself carries the same
checks as `task check` (fully offline) so correctness is re-verifiable
anywhere. No CLIs installed? `tests/run-in-docker.sh` runs the entire matrix
inside a pinned container (tofu + terraform + terragrunt + tflint + task +
conftest; docker or podman).

## Repo map

```
iac/
├── README.md, AGENTS.md      # you are here; AGENTS.md = guide for AI coding agents
├── docs/                     # conventions, placeholders, engine-duality, testing, references, migrations/, adr/, release-process
├── scripts/                  # init-project.{sh,ps1} + bootstrap.{sh,ps1} (one-liner entry)
├── tests/                    # run-all matrix runner, golden manifests, fixtures, emulators
└── templates/01..04/         # the four tier skeletons (self-contained)
```

## Future extensions (deliberately out of scope)

Copier/cookiecutter generator: decided — rejected in
`docs/adr/0001-one-liner-installer.md` (a second generator would fork the
tested init contract); the sanctioned follow-up is a vendored `npm create`
wrapper around the same bootstrap. Infracost stays deferred unless
requested. (CI is no longer on this list: tiers ship opt-in pipeline
skeletons — `init-project --ci github|gitlab` — running the same offline
checks `tests/run-all.sh` calls; tier 03/04 skeletons include a scheduled
drift job.)
