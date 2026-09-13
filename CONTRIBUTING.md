# Contributing — trunk-based workflow + commit conventions

How work lands in this repo. Followed by humans and by AI coding agents
(the root `AGENTS.md` points here for commit style).

## Branching model: trunk-based

- **`main` is the only long-lived branch.** Everyone commits straight to it.
- Work in place; do not open long-running feature branches. If a change is too
  large to review in one commit, land it as a short-lived branch (lifetime
  under a day) merged with a squash/fast-forward as soon as it's green.
- Never force-push `main`; never use `--amend` on a commit that has been pushed.

Rationale: this is a template catalog — small, reviewable commits beat merge
ceremony. Each tier's generated project carries its own workflow guidance;
this policy is for the catalog repo only.

## Commit style (Conventional Commits)

One-line subject + `type(scope)` prefix, then a blank line, then one
`- ` bullet per notable change. Max ~72 columns on the subject.

```
feat(playground): disposable LocalStack harness to apply all 4 tiers

- compose.yml: single file (localstack + azurite), community image pinned
- up.sh: instantiate 4 tiers, localize, boot emulators, bootstrap backend
- docs: testing.md T6 section rewired to the harness
```

### Types

| Type | Use for |
|------|---------|
| `feat` | new capability (a file, a task, a tier, a script) |
| `fix` | correcting a defect |
| `docs` | documentation-only changes |
| `test` | tests/fixtures/manifests only (no source behavior change) |
| `refactor` | behavior-preserving restructuring |
| `chore` | tooling, ignore rules, CI wiring, non-functional |

### Scopes

Match the area touched, singular, `kebab-case`. Common ones:

`init` `templates`/`tier-01`…`tier-04` `scripts` `tests` `docs`
`playground` `providers` `ci`. Omit the scope when the change spans the whole
repo (`chore:` or a repo-wide `feat:`).

### Rules

1. Subject is imperative, present tense ("add", "fix", "remove" — not "added").
2. Body bullets describe **behavior**, not trivia; each ties to a file/area.
3. Never commit secrets, `.env`, `*.tfstate`, plan files, or the generated
   `playground/projects/` and `tests/scratch/` trees (all gitignored).
4. One concern per commit. Cross-cutting changes to `docs/conventions.md` must
   update all four tiers **in the same commit** (see root `AGENTS.md` house
   rule 1), and a token change updates `docs/placeholders.md` + both init
   scripts together.
5. End the body with a verification line when it materially changed behavior,
   e.g. `Verified: tests/run-in-docker.sh 103 pass / 0 fail / 30 skip.`

## Before committing

1. Follow the root `AGENTS.md` "Verification protocol" for the change's blast
   radius (at minimum `bash -n` on touched `.sh`, `.ps1` parse check).
2. `git status` + `git diff` — stage only intended files; review for stray
   state/logs/secrets.
3. Keep `main` green: the authoritative gate is
   `tests/run-in-docker.sh` (or `tests/run-all.sh` when CLIs exist). Run the
   subset your change touches.

## Releases

Tags are cut directly on green `main` (trunk-based — no release branches)
following the checklist in `docs/release-process.md`: semver where a breaking
change to generated output — or a tofu/terraform/terragrunt major that breaks
generated configs — is a MAJOR, and every release attaches a `checksums.txt`
(the one-liner installer verifies it; see
`docs/adr/0001-one-liner-installer.md`). Tagging and publishing are owner
actions: agents never tag or push releases.

## Commit message for AI agents

When an agent is asked to "commit this", it must: inspect `git status`,
`git diff`, and `git log --oneline -8` first; stage only the intended files;
write a Conventional Commit matching the style above; and never push or
amend unless explicitly told to.
