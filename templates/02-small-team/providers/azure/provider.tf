terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Authentication comes from environment variables (never commit secrets -
  # copy .env.example to .env, which is gitignored):
  #   ARM_SUBSCRIPTION_ID  - REQUIRED by azurerm v4 (backend AND provider)
  #   ARM_TENANT_ID / ARM_CLIENT_ID / ARM_CLIENT_SECRET  - service principal
  # Interactive alternative: `az login` with ARM_SUBSCRIPTION_ID still set.
  # subscription_id may also be set in this block instead of the env var.
}
