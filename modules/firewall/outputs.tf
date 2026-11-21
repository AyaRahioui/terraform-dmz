# Contrat d'interface : ne pas renommer ces outputs sans prévenir M1/M3.

output "nva_vm_id" {
  value = azurerm_linux_virtual_machine.nva.id
}

output "nva_nic_id" {
  value = azurerm_network_interface.nva.id
}

output "nva_private_ip" {
  description = "IP de eth0 = next hop des UDR (M3). Connue dès le plan si private_ip_address est fixée."
  value       = azurerm_network_interface.nva.ip_configuration[0].private_ip_address
}

output "nva_public_ip" {
  description = "IP publique de la NVA (DNAT 80/443 -> vm-web)."
  value       = azurerm_public_ip.nva.ip_address
}

# --- Outputs ajoutés par M2 ---

output "nva_trust_nic_id" {
  description = "ID de la NIC trust (eth1), null si enable_trust_nic = false."
  value       = one(azurerm_network_interface.trust[*].id)
}

output "nva_trust_private_ip" {
  value = one(azurerm_network_interface.trust[*].private_ip_address)
}

output "nftables_ruleset" {
  description = "Ruleset nftables rendu (avant remplacement de __NVA_IP__ au boot). Pour revue et tests."
  value       = local.nftables_conf
}
