# -----------------------------------------------------------------------------
# policy/tags.rego - mandatory tags on every taggable planned resource.
#
# WHAT the mandatory tags ARE is defined in common/tags.hcl
# (locals.mandatory_tags); this file ENFORCES that definition at plan time:
#
#   <engine> show -json tfplan > tfplan.json
#   conftest test tfplan.json -p policy/
#
# Pragmatic ruleset:
#   - a planned resource that HAS a tag map (AWS `tags`, Azure `tags`, GCP
#     `labels`) MUST define every mandatory tag KEY on it;
#   - a tag map of null counts as MISSING tags (deny);
#   - resources without a tags/labels attribute PASS (no tag support);
#   - destroy-only changes have an empty `after` and PASS.
#
# Sync rule: `mandatory_tags` below MUST mirror common/tags.hcl.
#
# Tip: with the AWS provider uncommented and default_tags wired to
# common_tags (platforms/aws/root.hcl), taggable AWS resources inherit the
# mandatory tags automatically and pass this policy without module changes.
# -----------------------------------------------------------------------------

package terraform.plan

# Bridge syntax: no-ops on OPA v1.x, enablers on recent v0.x.
import future.keywords.if
import future.keywords.contains

# MUST mirror common/tags.hcl locals.mandatory_tags keys.
mandatory_tags = {"Project", "ManagedBy"}

# Attribute names the three clouds use for their tag maps.
tag_attributes = {"tags", "labels"}

# Key set of a tag map (empty set for null/empty maps).
tag_keys(t) = {key | t[key]}

has_mandatory_tags(t) if {
  count(tag_keys(t) & mandatory_tags) == count(mandatory_tags)
}

deny contains msg if {
  rc := input.resource_changes[_]
  attr := tag_attributes[_]
  # object.get default `false` distinguishes "no tag attribute" (pass) from
  # "attribute present" - including present-but-null (deny).
  tags := object.get(rc.change.after, attr, false)
  tags != false
  not has_mandatory_tags(tags)
  missing := mandatory_tags - tag_keys(tags)
  msg := sprintf(
    "%s (%s): %s must define mandatory tag(s) [%s] - defined in common/tags.hcl, enforced by policy/tags.rego",
    [rc.address, rc.type, attr, concat(", ", sort(missing))],
  )
}
