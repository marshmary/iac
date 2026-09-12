# -----------------------------------------------------------------------------
# policy/tests/tags_test.rego - unit tests for policy/tags.rego.
#
# Run with: conftest verify --policy policy/   (no plan needed; wired into
# `task policy-verify` and tests/run-all.sh T5).
#
# `deny` is the UNION of every rule file in package terraform.plan, so these
# mocks use aws_dynamodb_table / google_compute_instance: they carry a
# `tags`/`labels` map but are NOT in naming.rego's named_resources, which
# keeps the expected deny counts attributable to the tag rules alone.
# -----------------------------------------------------------------------------
package terraform.plan

plan_doc(resources) := {"resource_changes": resources}

compliant_table := {
  "address": "aws_dynamodb_table.ok",
  "type": "aws_dynamodb_table",
  "change": {"after": {"tags": {"Project": "demo", "ManagedBy": "iac", "Extra": "free-form"}}},
}

missing_managed_by := {
  "address": "aws_dynamodb_table.missing",
  "type": "aws_dynamodb_table",
  "change": {"after": {"tags": {"Project": "demo"}}},
}

null_tags := {
  "address": "aws_dynamodb_table.null",
  "type": "aws_dynamodb_table",
  "change": {"after": {"tags": null}},
}

no_tag_attribute := {
  "address": "aws_dynamodb_table.plain",
  "type": "aws_dynamodb_table",
  "change": {"after": {"hash_key": "Id"}},
}

destroy_only := {
  "address": "aws_dynamodb_table.gone",
  "type": "aws_dynamodb_table",
  "change": {"after": null},
}

compliant_labels := {
  "address": "google_compute_instance.ok",
  "type": "google_compute_instance",
  "change": {"after": {"labels": {"Project": "demo", "ManagedBy": "iac"}}},
}

test_compliant_tags_pass {
  denied := deny with input as plan_doc([compliant_table])
  count(denied) == 0
}

test_missing_mandatory_key_denies {
  d := deny with input as plan_doc([missing_managed_by])
  count(d) == 1
  contains(d[_], "ManagedBy")
}

test_null_tag_map_counts_as_missing {
  denied := deny with input as plan_doc([null_tags])
  count(denied) == 1
}

test_resource_without_tag_attribute_passes {
  denied := deny with input as plan_doc([no_tag_attribute])
  count(denied) == 0
}

test_destroy_only_change_passes {
  denied := deny with input as plan_doc([destroy_only])
  count(denied) == 0
}

test_gcp_labels_checked_like_tags {
  denied := deny with input as plan_doc([compliant_labels])
  count(denied) == 0
}
