## Summary

<!-- What changes and why. Link the issue/ticket if one exists. -->

## Environments affected

- [ ] dev
- [ ] staging
- [ ] prod - requires a reviewed tfplan and two reviewers (CODEOWNERS)

## Plan summary

<!--
Run `task plan ENV=<env>` for each affected env and paste the condensed
summary (e.g. "Plan: 2 to add, 1 to change, 0 to destroy").
Do not paste full plans if they may contain sensitive values.
-->

## Checklist

- [ ] Plan output pasted above and reviewed by at least one teammate
- [ ] `.terraform.lock.hcl` changes committed (or explicitly none)
- [ ] Resources follow the tagging convention (Project / Env / ManagedBy)
- [ ] Module docs regenerated for changed modules (`pre-commit run terraform_docs`; markers intact)
- [ ] `task check ENV=<env>` passes for every affected env
