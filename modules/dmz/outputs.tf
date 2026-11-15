output "web_vm_id" {
  value = azurerm_linux_virtual_machine.web.id
}

output "web_nic_id" {
  value = azurerm_network_interface.web.id
}

output "web_private_ip" {
  value = azurerm_network_interface.web.private_ip_address
}