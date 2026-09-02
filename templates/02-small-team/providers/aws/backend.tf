# Remote state backend - SHARED bucket, one key per env.
# The bucket, DynamoDB lock table and region are created in bootstrap/aws.md.

terraform {
  backend "s3" {
    bucket         = "__STATE_BUCKET__"
    key            = "__PROJECT_NAME__/__ENV__/terraform.tfstate"
    region         = "__REGION__"
    dynamodb_table = "__DYNAMO_TABLE__"
    encrypt        = true
  }
}
