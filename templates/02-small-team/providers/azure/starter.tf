# Example starter resource - proves the wiring end-to-end.
# REPLACE with real infrastructure; keep the tag convention.
resource "azurerm_resource_group" "starter" {
  name     = "rg-__PROJECT_NAME__-__ENV__-starter"
  location = "__REGION__"

  tags = {
    Project   = "__PROJECT_NAME__"
    Env       = "__ENV__"
    ManagedBy = "iac"
  }
}
