mock_provider "azurerm" {}
mock_provider "random" {}

run "lan_basic" {
  command = plan

  variables {
    resource_group_name = "rg-test"
    location            = "germanywestcentral"
    name_prefix         = "test"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-x"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIECAtgSfxL4M6hKdzOTD6VCS2f9IdTa4wTwkHhf8jCDZ test@example" // The ssh_public_key is a dummy string for the test. Never put a real key there!
  }

  assert {
    condition     = azurerm_network_interface.app.ip_configuration[0].private_ip_address == "10.10.2.4"
    error_message = "vm-app must have IP 10.10.2.4."
  }

  assert {
    condition     = azurerm_network_interface.db.ip_configuration[0].private_ip_address == "10.10.2.5"
    error_message = "vm-db must have IP 10.10.2.5."
  }
}