# Example resource — REPLACE with real infrastructure, then delete this file.
# Azure naming: rg-<project>-<suffix>; location is an Azure region name such
# as "westeurope" or "uksouth" (substitute the region you chose).
resource "azurerm_resource_group" "starter" {
  name     = "rg-__PROJECT_NAME__-starter"
  location = "__REGION__"

  tags = local.common_tags
}
