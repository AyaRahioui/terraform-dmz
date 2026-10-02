mock_provider "azurerm" {}

run "bastion_ssh_keys_only" {
  command = plan

  variables {
    resource_group_name = "rg-test"
    location            = "germanywestcentral"
    name_prefix         = "test"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-mgmt"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest test"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.bastion.disable_password_authentication == true
    error_message = "Le mot de passe SSH doit être désactivé."
  }
}
