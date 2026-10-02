output "bastion_public_ip" {
  value = module.mgmt.bastion_public_ip
}

output "nva_private_ip" {
  value = module.firewall.nva_private_ip
}

output "web_private_ip" {
  value = module.dmz.web_private_ip
}

output "app_private_ip" {
  value = module.lan.app_private_ip
}

output "db_private_ip" {
  value = module.lan.db_private_ip
}

output "monitoring_private_ip" {
  value = module.monitoring.monitoring_private_ip
}
