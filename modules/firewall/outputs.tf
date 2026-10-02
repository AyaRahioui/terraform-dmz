# Contrat d'interface : ne pas renommer ces outputs sans prévenir M1/M3.

output "nva_vm_id" {
  value = "" # TODO M2 : azurerm_linux_virtual_machine.nva.id
}

output "nva_nic_id" {
  value = "" # TODO M2 : azurerm_network_interface.nva.id
}

output "nva_private_ip" {
  value = "10.10.0.4" # TODO M2 : azurerm_network_interface.nva.private_ip_address
}

output "nva_public_ip" {
  value = "" # TODO M2 : azurerm_public_ip.nva.ip_address (utile pour le DNAT)
}
