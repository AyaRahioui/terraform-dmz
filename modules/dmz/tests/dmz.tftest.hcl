# M4 unit tests. Azure resources are mocked: no subscription or deployment needed.
# Run from modules/dmz: terraform init -backend=false && terraform test
mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-test"
  location            = "germanywestcentral"
  name_prefix         = "test"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-dmz"
  ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiTxjQDodmFczuEOaDaya09KPZ9QLgIrZXpRRK1wlZu dell@DESKTOP-7GUOITQ"
}

run "names_follow_the_contract" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.web.name == "vm-test-web"
    error_message = "VM name must be vm-<name_prefix>-web."
  }
  assert {
    condition     = azurerm_network_interface.web.name == "nic-test-web"
    error_message = "NIC name must be nic-<name_prefix>-web."
  }
}

run "ssh_key_only_and_no_public_ip" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.web.disable_password_authentication == true
    error_message = "Password authentication must be disabled."
  }
  assert {
    condition = contains(
      [for key in azurerm_linux_virtual_machine.web.admin_ssh_key : key.public_key],
      var.ssh_public_key
    )
    error_message = "VM must use the supplied SSH public key."
  }
  assert {
    condition     = azurerm_network_interface.web.ip_configuration[0].public_ip_address_id == null
    error_message = "vm-web must not have a public IP."
  }
}

run "static_ip_from_addressing_plan" {
  command = plan
  variables {
    private_ip_address = "10.10.1.4"
  }
  assert {
    condition     = azurerm_network_interface.web.ip_configuration[0].private_ip_address_allocation == "Static"
    error_message = "A supplied IP must use Static allocation."
  }
  assert {
    condition     = azurerm_network_interface.web.ip_configuration[0].private_ip_address == "10.10.1.4"
    error_message = "NIC must use the assigned DMZ IP."
  }
}

run "dynamic_ip_when_unspecified" {
  command = plan
  assert {
    condition     = azurerm_network_interface.web.ip_configuration[0].private_ip_address_allocation == "Dynamic"
    error_message = "Without an assigned IP, allocation must be Dynamic."
  }
}

run "cloud_init_includes_configuration" {
  command = plan
  assert {
    condition     = strcontains(base64decode(azurerm_linux_virtual_machine.web.custom_data), "BACKEND_IP='10.10.2.4'")
    error_message = "Cloud-init must receive the configured backend IP."
  }
  assert {
    condition     = strcontains(base64decode(azurerm_linux_virtual_machine.web.custom_data), "BACKEND_PORT='8080'")
    error_message = "Cloud-init must receive the backend port."
  }
  assert {
    condition     = strcontains(base64decode(azurerm_linux_virtual_machine.web.custom_data), "BASTION_IP='10.10.3.4'")
    error_message = "Cloud-init must receive the bastion IP."
  }
  assert {
    condition     = strcontains(base64decode(azurerm_linux_virtual_machine.web.custom_data), "SecRuleEngine On")
    error_message = "Cloud-init must enable ModSecurity blocking."
  }
}
