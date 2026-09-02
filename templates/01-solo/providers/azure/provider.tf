# Azure provider — merged into the project root at instantiation.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Empty features block is required by azurerm 4.x; defaults are fine here.
  features {}
}

# Authentication is environment-based (no secrets in code). Required vars:
#   ARM_SUBSCRIPTION_ID  subscription to deploy into
#   ARM_CLIENT_ID        service principal (app) id — or `az login` for humans
#   ARM_CLIENT_SECRET    service principal secret
#   ARM_TENANT_ID        Entra ID tenant id
# Names are listed in .env.example; copy to .env (gitignored) or export them.
