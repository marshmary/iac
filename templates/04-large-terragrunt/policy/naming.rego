# -----------------------------------------------------------------------------
# policy/naming.rego - project + env tokens in resource names.
#
# Deliberately SIMPLE (keep it that way): it demonstrates the naming gate on
# three sample resource types - one per cloud. Extend `named_resources` as
# the catalog grows; keep checks mechanical (substring present / absent) so
# every failure is immediately actionable.
#
# Convention: <project>-<env>-<name>, e.g. acme-dev-artifacts. GCP names are
# lowercase with no underscores - the substring checks work under any
# separator style, so one rule set covers all three clouds.
#
# The project token below is substituted at init time (same token as
# everywhere else in the tree). `environments` must stay in sync with the
# directories under platforms/*/envs/ and the keys of common/accounts.hcl.
# -----------------------------------------------------------------------------

package terraform.plan

# Bridge syntax: no-ops on OPA v1.x, enablers on recent v0.x.
import future.keywords.if
import future.keywords.in
import future.keywords.contains

# Project identifier - substituted by init (mirrors __PROJECT_NAME__ tokens).
project_name = "__PROJECT_NAME__"

# Known environments - keep in sync with platforms/*/envs/ and
# common/accounts.hcl.
environments = {"dev", "prod"}

# Resource types checked, mapped to the attribute holding the name
# ("bucket" for aws_s3_bucket - not "name").
# Extend this map first when adding coverage; the two rules below are generic.
named_resources = {
  "aws_s3_bucket": "bucket",
  "azurerm_resource_group": "name",
  "google_storage_bucket": "name",
}

# Names of listed resources must contain the project token.
deny contains msg if {
  some rtype, name_attr in named_resources
  rc := input.resource_changes[_]
  rc.type == rtype
  name := object.get(rc.change.after, name_attr, "")
  name != ""
  not contains(name, project_name)
  msg := sprintf(
    "%s (%s): name %q must contain the project token %q (expected <project>-<env>-<name>) - see policy/naming.rego",
    [rc.address, rc.type, name, project_name],
  )
}

# Names of listed resources must contain an environment token.
deny contains msg if {
  some rtype, name_attr in named_resources
  rc := input.resource_changes[_]
  rc.type == rtype
  name := object.get(rc.change.after, name_attr, "")
  name != ""
  not has_env_token(name)
  msg := sprintf(
    "%s (%s): name %q must contain an environment token (one of [%s]) - see policy/naming.rego",
    [rc.address, rc.type, name, concat(", ", sort(environments))],
  )
}

has_env_token(name) if {
  some env in environments
  contains(name, env)
}
