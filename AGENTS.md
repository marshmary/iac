# AGENTS.md — guide for AI coding agents working on THIS template repo

This repo is a template catalog, not a deployed project. `templates/0X-*/` are
raw skeletons containing `__TOKEN__` placeholders; they only become valid
projects after `scripts/init-project.{sh,ps1}` transforms them. Agent work
here means: maintaining tiers, scripts, tests, and docs — never "fixing"
tokens by hardcoding values.

## Repo map

- `templates/01-solo/` — single root module, 1–2 envs, plain TF/TOFU
- `templates/02-small-team/` — per-env roots `envs/{dev,staging,prod}/` + `modules/`
- `templates/03-team-terragrunt/` — Terragrunt `root.hcl` + `envs/<env>/<component>/`
- `templates/04-large-terragrunt/` — `common/` registries + `platforms/{aws,azure,gcp}/` + `policy/` + `runbooks/`
- `scripts/init-project.{sh,ps1}` — instantiation (contract below)
- `tests/` — `run-all.{sh,ps1}` matrix runner, `manifests/` golden trees, fixtures
- `docs/` — conventions (authoritative), placeholders, engine-duality, testing, references, migrations
- Each tier folder also contains its own `AGENTS.md` — that one ships INTO
  generated projects and guides agents working there. Keep the two audiences separate.

## House rules

1. `docs/conventions.md` is the contract every tier obeys. A change to it must
   be applied to all four tiers in the same commit, or explicitly justified as
   tier-scoped.
2. Tokens stay greppable: `__[A-Z0-9_]+__` only, from the list in
   `docs/placeholders.md`. Never split, lowercase, or "pre-substitute" them.
3. Engine duality is non-negotiable: no `terraform`/`tofu` hardcoded in docs,
   tasks, or comments that prescribe commands. Tasks resolve the binary via
   `IAC_ENGINE` (see any tier's `Taskfile.yml`).
4. Windows-safe repo: LF endings, no symlinks, no bash-isms in PowerShell,
   PowerShell 5.1-compatible syntax in `.ps1` (no `??`, no ternary).
5. Generated projects must be self-contained: tier files may reference
   `docs/conventions.md`, `docs/engine-duality.md`, `docs/migrations/` (init
   copies those in) but never `../../` paths back to this catalog.
6. Provider/cloud specifics live only in `providers/<cloud>/` (tiers 01–02),
   the injectable `root-provider.hcl` (tier 03), or `platforms/<cloud>/`
   (tier 04). Everything else stays cloud-neutral.
7. Starter examples that need no cloud credentials for planning are a feature
   (`terraform_data`-based modules, commented provider blocks in Terragrunt
   tiers). Do not break offline planning.

## Init-script contract (changing tiers or scripts? keep these in sync)

| Tier | providers/ handling | Where merged files land |
|------|---------------------|------------------------|
| 01 | copy every `providers/<cloud>/*.tf` (backend, provider, starter, cloud-only variables) + `providers/<cloud>/tests/` (per-cloud mock test files), then delete `providers/` | project root |
| 02 | same `.tf` files copied into EVERY `envs/*/` dir, `__ENV__` → dir name, then delete `providers/` | each `envs/<env>/` |
| 03 | `providers/<cloud>/root-provider.hcl` injected into `root.hcl` between the `>>> CLOUD PROVIDER` / `<<< END CLOUD PROVIDER` markers, then delete `providers/` | `root.hcl` |
| 04 | nothing stripped — all `platforms/` retained; tokens substituted per-platform (`platforms/aws/**` gets AWS defaults, etc.) | in place |

After merge: global token substitution (defaults in `docs/placeholders.md`),
copy `docs/{conventions.md,engine-duality.md,migrations/}` into the project,
`git init` (unless `--no-git`), fail if any `__[A-Z0-9_]+__` remains.

## Verification protocol before you claim done

1. `bash -n scripts/*.sh tests/*.sh` — syntax.
2. PowerShell parse check on `.ps1` files.
3. `tests/gen-manifests.sh` — regenerate golden manifests; review the diff.
4. `tests/run-in-docker.sh` — the full T0–T5 matrix in the pinned runner
   container (docker/podman auto-detected; no host CLIs needed). This is the
   authoritative gate. Plain `tests/run-all.sh` works too when CLIs exist;
   with none installed it still runs T0 (init + manifest compare + sweep).
5. Structural sweep: every tier has `AGENTS.md`, `README.md`, `Taskfile.yml`,
   `.pre-commit-config.yaml`, `.tflint.hcl`, both version-pin files
   (+ `.terragrunt-version` for tiers 03/04).

## Where new content goes

- New shared rule → `docs/conventions.md` + mirror in all tiers' behavior.
- New token → `docs/placeholders.md` + both init scripts + relevant tiers.
- New check → `tests/run-all.{sh,ps1}` + `docs/testing.md`.
- New migration guide → `docs/migrations/NN-to-MM.md`.
- New tier → extend the table above, README, run-all, and gen-manifests.
