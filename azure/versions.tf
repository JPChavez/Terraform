terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Key is passed at init time via -backend-config to support multiple environments:
  #   terraform init -reconfigure -backend-config="key=azure/dev.terraform.tfstate"
  #   terraform init -reconfigure -backend-config="key=azure/uat.terraform.tfstate"
  #   terraform init -reconfigure -backend-config="key=azure/prod.terraform.tfstate"
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-jproject"
    storage_account_name = "stjprojecttfstate"
    container_name       = "tfstate"
  }
}
