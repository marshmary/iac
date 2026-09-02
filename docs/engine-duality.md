# Engine duality — running Terraform and OpenTofu from one template

Every tier runs unchanged on **OpenTofu** (default) or **Terraform**. You
should never type a bare `terraform`/`tofu` command — tasks resolve the
binary for you.

## Mechanism

1. `required_version = ">= 1.11.0, < 2.0.0"` — satisfied by both engines
   (Terraform 1.11+ and OpenTofu 1.11+).
2. Both pin files ship: `.terraform-version` (tfenv/tenv) and
   `.opentofu-version` (tofuenv/tenv), pinned independently — Terraform
   `1.16.0`, OpenTofu `1.12.0` — so the version manager of whichever engine
   you use installs that engine's own pin.
3. Every Taskfile resolves the binary:

   ```
   IAC_ENGINE=tofu (default) or terraform
   IAC_BIN = $IAC_ENGINE if on PATH, else terraform if on PATH, else $IAC_ENGINE
   ```

   Terragrunt tiers forward it via `--tf-path {{.IAC_BIN}}`.

4. Switching engines on an existing project: `IAC_ENGINE=terraform task plan`.

## Lockfile caveat

Both engines read/write `.terraform.lock.hcl`, but OpenTofu records **both**
`h1:` and zip `zh:` provider hashes while Terraform records `h1:` (and its own
zip `zh:` set). After switching engines, regenerate to avoid checksum noise:

```
rm .terraform.lock.hcl && task init-backend   # re-lock with the active engine
```

Commit the regenerated lockfile. Provider versions themselves are identical —
only the recorded hashes differ.

## State locking (AWS S3 backend)

The AWS S3 backend uses S3-native locking (`use_lockfile = true`) instead of a
DynamoDB table. Both engines support it: Terraform 1.11+ and OpenTofu 1.9+
(the `required_version` floor and both pins satisfy this). The lock object is
`<key>.tflock` next to the state object.

## What is engine-specific

- `mock_providers` / native test mocks: **OpenTofu only**. Tier `test` tasks
  detect the resolved binary and skip with a message on Terraform, which
  relies on `task check` + `task plan` instead.
- Everything else (config syntax, providers, backends, Terragrunt usage) is
  identical for both engines.

## CI later

Any future pipeline just sets `IAC_ENGINE` and calls the same tasks —
engine choice is one variable, not a fork of the workflow.
