output "app_vm_id" {
  value = azurerm_linux_virtual_machine.app.id
}

output "db_vm_id" {
  value = azurerm_linux_virtual_machine.db.id
}

output "app_private_ip" {
  value = azurerm_network_interface.app.private_ip_address
}

output "db_private_ip" {
  value = azurerm_network_interface.db.private_ip_address
}
