# Release process

How catalog versions are cut, and how the one-liner installer
(`docs/adr/0001-one-liner-installer.md`) stays verifiable. The audience for
the checklist is the **repo owner**: agents never tag, push tags, or publish
releases (see `CONTRIBUTING.md`). Trunk-based flow is unchanged — this
process adds tags to `main`, not branches.

## Versioning (semver)

| Bump | When | Examples |
|------|------|----------|
| MAJOR | Breaking change to generated project structure or behavior — including adopting a tofu / terraform / terragrunt **major** whose changes break the generated configs | new token vocabulary; renamed tier layout; engine major with removed features the templates rely on |
| MINOR | Additive capability — new token, new init/bootstrap flag, new tier file; **version-pin bumps that keep generated projects valid** (they change output bytes, not behavior) | `--ci gitlab` support; new provider starter; `.opentofu-version` bump that still validates + plans |
| PATCH | Fixes with no intentional generated-output change | doc typo; init-script error message; bootstrap bug |

Rule of thumb: if a user re-running the installer at the new version can get
a project that behaves differently in a breaking way, it is a MAJOR. When in
doubt between MINOR and PATCH, choose MINOR.

## Branching and tags

- Tags are annotated and cut directly on green `main`; there are no release
  branches and no cherry-pick trains.
- Never re-point or delete a pushed tag: released tarballs and their
  `checksums.txt` are immutable once published.

## `checksums.txt` format contract

Exactly one line, produced by the default `sha256sum` invocation:

```
<64-char lowercase hex>␠␠catalog.tar.gz
```

(two spaces between hash and name — `sha256sum catalog.tar.gz >
checksums.txt` output, no CR). `scripts/bootstrap.sh` / `.ps1` parse exactly
this: first field of the line whose second field is `catalog.tar.gz`. Every
release attaches one; the strict checksum policy in the bootstrap refuses to
install a tagged release without it.

## Checklist for vX.Y.Z

Run from a clone with `main` checked out.

1. **Green gate:** `tests/run-in-docker.sh` (or `tests/run-all.sh` when host
   CLIs exist) reports zero FAIL. T0 alone is not enough for a release.
2. **Tag:** `git tag -a vX.Y.Z -m "release vX.Y.Z"` then
   `git push origin vX.Y.Z`.
3. **Tarball:** `curl -fL -o catalog.tar.gz https://github.com/marshmary/iac/archive/refs/tags/vX.Y.Z.tar.gz`
4. **Checksum:** `sha256sum catalog.tar.gz > checksums.txt` — verify it
   matches the format contract above (one line, two spaces, `.tar.gz` name).
5. **Publish:** create the GitHub Release for the tag and attach
   `checksums.txt`, e.g.
   `gh release create vX.Y.Z checksums.txt --title vX.Y.Z --notes "…"`.
6. **Smoke-test both one-liners** from a scratch directory *outside* the
   repo, in default mode (no `--ref`/`-Ref`):
   - `curl -fsSL https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.sh | bash -s -- -t 01 -p aws -n smoke-test -d /tmp/smoke`
   - `Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/marshmary/iac/main/scripts/bootstrap.ps1) } -Tier 01 -Provider aws -Name smoke-test -Dest C:\temp\smoke"`
   - and the flagless forms (interactive chooser must engage).
7. **If this was the first release:** remove the interim `--ref main` note
   from the README quickstart (added when the one-liner shipped).

## Renovate interplay

Renovate keeps the catalog's own tool pins current as one grouped weekly PR.
Merging a pin bump that changes generated output ships in the next MINOR at
least (pin bumps are never PATCH by the table above). The pinned-release
installer means consumers only see the change when they opt into the new
version.
