terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # State stored in the same Azure Blob Storage backend, under a gcp/ prefix.
  # Key is passed at init time via -backend-config to support multiple environments:
  #   terraform init -reconfigure -backend-config="key=gcp/dev.terraform.tfstate"
  #   terraform init -reconfigure -backend-config="key=gcp/uat.terraform.tfstate"
  #   terraform init -reconfigure -backend-config="key=gcp/prod.terraform.tfstate"
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-jproject"
    storage_account_name = "stjprojecttfstate"
    container_name       = "tfstate"
  }
}
