mock_provider "azurerm" {}

run "dmz_basic" {
  command = plan

  variables {
    resource_group_name = "rg-test"
    location            = "germanywestcentral"
    name_prefix         = "test"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-x"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest test"
  }
}
