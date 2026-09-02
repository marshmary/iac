# Example starter resource - proves the wiring end-to-end.
# REPLACE with real infrastructure; keep the tag convention.
resource "aws_s3_bucket" "starter" {
  bucket = "__PROJECT_NAME__-__ENV__-starter"

  tags = {
    Project   = "__PROJECT_NAME__"
    Env       = "__ENV__"
    ManagedBy = "iac"
  }
}
