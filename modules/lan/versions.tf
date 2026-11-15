terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    // The DB password is generated and never stored in Git
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
