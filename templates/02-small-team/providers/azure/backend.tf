# Remote state backend - SHARED container, one key per env.
# Resource group, storage account and container are created in
# bootstrap/azure.md. Authentication uses the same ARM_* environment
# variables as the provider.

terraform {
  backend "azurerm" {
    resource_group_name  = "__STATE_RESOURCE_GROUP__"
    storage_account_name = "__STATE_STORAGE_ACCOUNT__"
    container_name       = "__STATE_CONTAINER__"
    key                  = "__PROJECT_NAME__/__ENV__/terraform.tfstate"
  }
}
