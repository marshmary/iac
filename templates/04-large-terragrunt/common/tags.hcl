# -----------------------------------------------------------------------------
# common/tags.hcl - mandatory tag policy, single source of truth.
#
# WHAT is defined HERE; policy/tags.rego enforces it at plan time
# (`task policy-check`). The two files must stay in sync: the rego rule's
# `mandatory_tags` set mirrors `locals.mandatory_tags` below. If you change
# one, change the other in the same commit.
#
# Every taggable planned resource (AWS `tags`, Azure `tags`, GCP `labels`)
# must carry all mandatory tag KEYS. Values are free-form but should stay
# team-greppable.
# -----------------------------------------------------------------------------

locals {
  # Mandatory on every taggable resource. Enforced by policy/tags.rego.
  mandatory_tags = {
    Project   = "__PROJECT_NAME__"
    ManagedBy = "iac"
  }

  # Optional tags - conventions, NOT enforced by policy. Set them per
  # component input or per team; they exist so cost allocation and on-call
  # routing have somewhere to live without a policy change.
  optional_tags = {
    # Owner      = "team-email@__PROJECT_NAME__.example"
    # CostCenter = "CC-1234"
    # Ticket     = "OPS-42"
  }
}
