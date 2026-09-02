# Runbook - state incidents (stuck lock / import / recovery)

Audience: component owners and on-call. Read fully before touching anything.

## GOLDEN RULE

**Snapshot the state before touching it.** Every procedure below assumes you
did step 0 first. State is the only artifact you cannot rebuild from code.

```sh
# Step 0 - snapshot (pick your platform's line):
aws s3 cp s3://<state-bucket>/envs/dev/baseline/terraform.tfstate \
  ./state-backup-$(date +%Y%m%d-%H%M%S).tfstate
az storage blob download --account-name <storage-account> \
  --container-name <tfstate-container> --name envs/dev/baseline/terraform.tfstate \
  --file ./state-backup-$(date +%Y%m%d-%H%M%S).tfstate
gcloud storage cp gs://<state-bucket>/envs/dev/baseline/terraform.tfstate \
  ./state-backup-$(date +%Y%m%d-%H%M%S).tfstate
```

Store snapshots OUTSIDE the repo (the `.gitignore` blocks `*.tfstate` for a
reason - never commit one, even "temporarily").

## 1. Stuck state lock

Symptom: `Error acquiring the state lock` on plan/apply, long after any real
run ended. First: genuinely check nobody is running anything (team chat), and
that no CI pipeline is mid-apply.

### AWS (S3-native lock)

Locking uses a `.tflock` object next to the state object
(`<key>.tflock`). Prefer the engine's own unlock when it reports a lock ID:

```sh
cd platforms/aws/envs/dev/baseline && terragrunt force-unlock <LOCK_ID> --tf-path tofu
```

If the lock object is stale (no live run holds it), delete it manually:

```sh
aws s3 rm s3://<state-bucket>/envs/dev/baseline/terraform.tfstate.tflock
```

Only do this after confirming nobody is running and no CI pipeline is
mid-apply.

### Azure (blob lease)

```sh
az storage blob lease break \
  --account-name <storage-account> \
  --container-name <tfstate-container> \
  --blob-name envs/dev/baseline/terraform.tfstate \
  --lease-break-period 0
```

### GCP

No lock mechanism on the GCS backend - a "stuck lock" here means a concurrent
run; find and stop it. Versioning (bootstrap.md) covers the rest.

## 2. Import an existing resource into state

For adopting pre-existing cloud resources (also the tail of drift runbook
3c). There is no task wrapper - run terragrunt directly with the engine it
resolves:

```sh
task engine-check   # shows the binary tasks use; use the same one below

terragrunt import --tf-path tofu \
  --working-dir platforms/aws/envs/dev/baseline \
  aws_s3_bucket.imported_example my-imported-bucket-name
```

Then:

```sh
task plan PLATFORM=aws ENV=dev COMPONENT=baseline   # MUST show no diff for the resource
```

If it shows a diff, fix the component inputs FIRST (state must describe the
real resource), or re-check the import ID syntax - never "fix" it by editing
state.

## 3. Corrupted / damaged state

Symptoms: state fails to parse, resources vanished from state but exist in
the cloud, or a partial apply corrupted the document.

1. Snapshot (step 0) - even if the snapshot looks broken, keep it.
2. Prefer the versioning escape hatch over manual edits:
   - AWS: list object versions
     (`aws s3api list-object-versions --bucket <state-bucket> --prefix envs/dev/baseline/terraform.tfstate`),
     copy the last-known-good version down, re-upload it over the current key.
   - Azure: soft delete / versioning on the storage account, same pattern via
     portal or `az storage blob` commands.
   - GCP: `gcloud storage ls -a gs://<state-bucket>/envs/...` (generation
     numbers), copy the good generation back.
3. Pull -> edit -> push is the LAST resort, only for surgical fixes (e.g.
   removing one bogus resource block) and only with the snapshot from step 1
   in hand. Two people review the edited document before push.
4. After any recovery: `task plan` per affected component and reconcile
   remaining diffs via the drift runbook (import or codify), never by editing
   state again.

## 4. When to escalate

Anything involving prod state, or any pull/edit/push, gets a second human
before execution - same rule as `run-all-apply`. Write the incident up as a
postmortem comment in the component's `terragrunt.hcl` (see
drift-remediation.md step 4 for the format).
