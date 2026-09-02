# Runbook - drift detection and remediation

Audience: anyone on call for a platform/env. Timebox: 30 minutes to
classification, then decide.

## 1. Detect

Per component (the normal loop):

```sh
task plan PLATFORM=aws ENV=dev COMPONENT=baseline   # exit non-zero / shows diff
```

A plan that is not empty against an untouched repo IS drift - by definition.

Broader sweeps (per platform/env scope):

```sh
task run-all-plan PLATFORM=aws ENV=dev
task run-all-plan PLATFORM=azure ENV=prod
```

Cadence until CI lands: schedule a weekly `run-all-plan` per platform/env
(cron / calendar / CI nightly job when it exists - the task is the same one a
human runs, so results are comparable) and page the owning team on any
non-empty diff. Record who ran it and where the output lives.

## 2. Classify

Read the diff and pick exactly one:

| Class | Meaning | Typical evidence | Action |
| --- | --- | --- | --- |
| Intended | someone did the right thing out of band (hotfix, console tweak during an incident) | change logs show a human/team you can name; the change is good | codify it (step 3a) |
| Config drift | the cloud changed, or someone edited an IaC-managed attribute outside git | attribute differs, no corresponding PR, no incident | decide the canonical value (step 3b) |
| External change | the platform itself mutates resources (auto-tagging, autoscaling-touched fields, Azure hidden-tags) | diff is in platform-managed fields only | ignore/accept the noise; consider `lifecycle { ignore_changes = [...] }` in the registry module - PR to the registry, not a live-tree hack |

Evidence sources: AWS CloudTrail / Azure Activity Log / GCP Cloud Audit Logs,
filtered to the resource address in the plan diff, last 30 days.

## 3. Fix

### 3a. Intended change - codify it

Bring the repo up to reality:

1. Update the component inputs (or the registry module, via a pinned `?ref=`
   bump) so the plan matches reality.
2. `task plan` -> empty diff (or only the codified delta).
3. `task policy-check` -> pass. Then `task apply` if there is a delta.

### 3b. Unwanted change - revert it

Re-apply the reviewed state of record:

```sh
task plan PLATFORM=aws ENV=dev COMPONENT=baseline   # diff = the unwanted change, inverted
task policy-check PLATFORM=aws ENV=dev COMPONENT=baseline
task apply PLATFORM=aws ENV=dev COMPONENT=baseline
```

This DESTROYS the out-of-band change. Confirm with the person who made it
first (see the audit log from step 2).

### 3c. Resource never was in state - import it

If the diff exists because reality was never captured in state, follow the
import flow in `runbooks/state-incident.md` (never hand-edit state).

## 4. Record

Every drift event that reached step 3 gets a postmortem comment in the
component's `terragrunt.hcl`:

```hcl
# Drift postmortem 2026-09-02:
#   What: S3 bucket public-access block disabled in console during INCIDENT-42.
#   Root cause: console hotfix not codified.
#   Fix: codified as module input (iac-modules PR #61, ref v0.1.4).
#   Follow-up: console write access revoked for the deploy role.
```

One to five lines is enough. The point is that the next person reading the
component knows why a codification happened. For repeat offenders, promote the
follow-up into an issue tracker entry linked from the comment.
