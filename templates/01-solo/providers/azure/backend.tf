# Remote state: Azure Storage blob container.
# Create the resource group / storage account / container before the first
# `task init-backend` — copy-paste commands in bootstrap/azure.md — then fill
# in the placeholder values printed there.
terraform {
  backend "azurerm" {
    resource_group_name  = "__STATE_RESOURCE_GROUP__"
    storage_account_name = "__STATE_STORAGE_ACCOUNT__"
    container_name       = "__STATE_CONTAINER__"
    key                  = "__PROJECT_NAME__/terraform.tfstate"
  }
}
