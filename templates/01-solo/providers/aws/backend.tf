# Remote state: S3 bucket + DynamoDB lock table.
# Create BOTH before the first `task init-backend` — copy-paste commands in
# bootstrap/aws.md — then fill in the placeholder values printed there.
terraform {
  backend "s3" {
    bucket         = "__STATE_BUCKET__"
    key            = "__PROJECT_NAME__/terraform.tfstate"
    region         = "__REGION__"
    dynamodb_table = "__DYNAMO_TABLE__"
    encrypt        = true
  }
}
