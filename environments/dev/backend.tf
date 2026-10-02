# Backend distant : utilisé UNIQUEMENT par M1 pour l'intégration finale.
# Les autres membres font `terraform init -backend=false`.
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-dmz"
    storage_account_name = "sttfstatedmz2026"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
    use_azuread_auth     = true
  }
}
