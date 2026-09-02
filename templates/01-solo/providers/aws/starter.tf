# Example resource — REPLACE with real infrastructure, then delete this file.
# Shows the conventions: name = <project>-<suffix>, tags from local.common_tags
# (provider default_tags in provider.tf already adds Project and ManagedBy;
# the resource-level tags here add Env on top).
resource "aws_s3_bucket" "starter" {
  bucket = "__PROJECT_NAME__-starter"

  tags = local.common_tags
}
