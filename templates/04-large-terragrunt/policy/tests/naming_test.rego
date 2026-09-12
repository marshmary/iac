# -----------------------------------------------------------------------------
# policy/tests/naming_test.rego - unit tests for policy/naming.rego.
#
# Run with: conftest verify --policy policy/   (no plan needed; wired into
# `task policy-verify` and tests/run-all.sh T5).
#
# The mocks follow the `terraform show -json tfplan` shape: deny rules read
# input.resource_changes[].change.after. Compliant names are built from the
# policy's own `project_name` rule so the tests hold both in the raw template
# (where project_name is still the __PROJECT_NAME__ token) and in a generated
# project (where init has substituted it).
# -----------------------------------------------------------------------------
package terraform.plan

plan_doc(resources) := {"resource_changes": resources}

named(rtype, attr, value) := {
  "address": sprintf("%s.named", [rtype]),
  "type": rtype,
  "change": {"after": {attr: value}},
}

compliant_name := sprintf("%s-dev-artifacts", [project_name])

# Regression guard for the S3 attribute map: the rule reads `bucket`. Mapping
# `aws_s3_bucket` to a nonexistent attribute (e.g. `name`) makes object.get
# return "" and BOTH rules silently skip every S3 bucket - this test catches
# that because the bad name must produce denies.
test_s3_bucket_without_tokens_denies {
  denied := deny with input as plan_doc([named("aws_s3_bucket", "bucket", "unrelated-name")])
  count(denied) == 2
}

test_s3_bucket_compliant_name_passes {
  denied := deny with input as plan_doc([named("aws_s3_bucket", "bucket", compliant_name)])
  count(denied) == 0
}

test_s3_bucket_env_token_alone_is_not_enough {
  # carries an env token but not the project token -> exactly one deny
  denied := deny with input as plan_doc([named("aws_s3_bucket", "bucket", "dev-artifacts")])
  count(denied) == 1
}

test_resource_group_without_tokens_denies {
  denied := deny with input as plan_doc([named("azurerm_resource_group", "name", "rg-unrelated")])
  count(denied) == 2
}

test_resource_group_compliant_name_passes {
  denied := deny with input as plan_doc([named("azurerm_resource_group", "name", compliant_name)])
  count(denied) == 0
}

test_gcp_bucket_compliant_name_passes {
  denied := deny with input as plan_doc([named("google_storage_bucket", "name", compliant_name)])
  count(denied) == 0
}

test_unlisted_resource_type_skips {
  # aws_instance is not in named_resources and has no tag map -> nothing fires
  denied := deny with input as plan_doc([named("aws_instance", "ami", "ami-123")])
  count(denied) == 0
}

test_empty_name_attribute_skips {
  # the `name != ""` guard means an empty attribute is not a naming violation
  denied := deny with input as plan_doc([named("aws_s3_bucket", "bucket", "")])
  count(denied) == 0
}
