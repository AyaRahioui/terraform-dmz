# Sorties du squelette M1 : conserver les noms ET les cles historiques.
output "route_table_ids" {
  description = "Map des IDs de routes pour dmz, lan, mgmt, monitoring."
  value       = { for k, rt in azurerm_route_table.zone : k => rt.id }
}

output "nsg_ids" {
  description = "Map des NSG pour firewall, dmz, lan, mgmt, monitoring."
  value       = { for k, nsg in azurerm_network_security_group.zone : k => nsg.id }
}

output "nsg_names" {
  description = "Noms des NSG pour T07/Network Watcher."
  value       = { for k, nsg in azurerm_network_security_group.zone : k => nsg.name }
}
