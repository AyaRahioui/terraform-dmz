mock_provider "azurerm" {}

run "network_creates_five_subnets" {
  command = plan

  variables {
    resource_group_name = "rg-test"
    location            = "germanywestcentral"
    name_prefix         = "test"
  }

  assert {
    condition     = length(azurerm_subnet.this) == 5
    error_message = "Le module network doit créer 5 subnets."
  }
}
