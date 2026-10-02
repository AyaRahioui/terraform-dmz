output "vnet_id" {
  description = "ID du VNet."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Nom du VNet."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map nom => ID (firewall, dmz, lan, mgmt, monitoring)."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "subnet_cidrs" {
  description = "Map nom => CIDR."
  value       = var.subnets
}

output "subnet_firewall_id" {
  value = azurerm_subnet.this["firewall"].id
}

output "subnet_dmz_id" {
  value = azurerm_subnet.this["dmz"].id
}

output "subnet_lan_id" {
  value = azurerm_subnet.this["lan"].id
}

output "subnet_mgmt_id" {
  value = azurerm_subnet.this["mgmt"].id
}

output "subnet_monitoring_id" {
  value = azurerm_subnet.this["monitoring"].id
}
