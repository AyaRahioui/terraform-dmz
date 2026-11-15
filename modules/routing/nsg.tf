# Couche 1 : NSG par subnet du VNet reel (5 zones, PAS outside/inside).
# Les regles Fxx correspondent a la matrice des flux. F12/F13 (conntrack)
# sont implementees par M2 via nftables; le NSG Azure est stateful.
# ATTENTION : les IP des hôtes doivent correspondre a M1/M2/M4/M5/M6.
locals {
  nsg_subnets = {
    for zone in ["firewall", "dmz", "lan", "mgmt", "monitoring"] :
    zone => var.subnet_ids[zone]
  }

  nsg_rules = concat([
    {
      nsg   = "firewall", dir = "Inbound", prio = 110, flow = "F07", name = "F07-SSH-from-bastion"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.nva_private_ip], ports = ["22"]
    },
    {
      nsg   = "firewall", dir = "Inbound", prio = 180, flow = "UDR", name = "UDR-forwarded-interzone"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.dmz, var.subnet_cidrs.lan, var.subnet_cidrs.mgmt, var.subnet_cidrs.monitoring], dst = [var.subnet_cidrs.dmz, var.subnet_cidrs.lan, var.subnet_cidrs.mgmt, var.subnet_cidrs.monitoring], ports = ["*"]
    },
    {
      nsg   = "firewall", dir = "Inbound", prio = 190, flow = "UDR", name = "UDR-forwarded-internet"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.dmz, var.subnet_cidrs.lan, var.subnet_cidrs.mgmt, var.subnet_cidrs.monitoring], dst = ["Internet"], ports = ["*"]
    },
    {
      nsg   = "firewall", dir = "Inbound", prio = 195, flow = "F10", name = "F10-forwarded-Azure-platform"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.dmz, var.subnet_cidrs.lan, var.subnet_cidrs.mgmt, var.subnet_cidrs.monitoring], dst = ["168.63.129.16", "169.254.169.254"], ports = ["53", "80", "32526"]
    },
    {
      nsg   = "firewall", dir = "Inbound", prio = 4096, flow = "F11", name = "F11-Deny-Inbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "dmz", dir = "Inbound", prio = 110, flow = "F07", name = "F07-SSH-from-bastion"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.hosts.web], ports = ["22"]
    },
    {
      nsg   = "dmz", dir = "Inbound", prio = 4096, flow = "F04/F05", name = "Deny-Inbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 100, flow = "F02", name = "F02-Web-to-App"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.web], dst = [var.hosts.app], ports = [tostring(var.app_port)]
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 110, flow = "F08", name = "F08-Logs"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.dmz], dst = [var.hosts.monitor], ports = var.monitoring_ports
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 120, flow = "F09", name = "F09-Updates"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.dmz], dst = ["Internet"], ports = ["80", "443"]
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 4096, flow = "F04/F05", name = "Deny-Outbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "lan", dir = "Inbound", prio = 100, flow = "F02", name = "F02-Web-to-App"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.web], dst = [var.hosts.app], ports = [tostring(var.app_port)]
    },
    {
      nsg   = "lan", dir = "Inbound", prio = 110, flow = "F03", name = "F03-App-to-DB"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.app], dst = [var.hosts.db], ports = [tostring(var.db_port)]
    },
    {
      nsg   = "lan", dir = "Inbound", prio = 120, flow = "F07", name = "F07-SSH-from-bastion"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.subnet_cidrs.lan], ports = ["22"]
    },
    {
      nsg   = "lan", dir = "Inbound", prio = 4096, flow = "F04/F05", name = "Deny-Inbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 100, flow = "F03", name = "F03-App-to-DB"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.app], dst = [var.hosts.db], ports = [tostring(var.db_port)]
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 110, flow = "F08", name = "F08-Logs"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.lan], dst = [var.hosts.monitor], ports = var.monitoring_ports
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 120, flow = "F09", name = "F09-Updates"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.lan], dst = ["Internet"], ports = ["80", "443"]
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 4096, flow = "F04/F05", name = "Deny-Outbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "mgmt", dir = "Inbound", prio = 4096, flow = "F05", name = "Deny-Inbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 100, flow = "F07", name = "F07-Admin-SSH"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.nva_private_ip, var.hosts.web, var.hosts.app, var.hosts.db, var.hosts.monitor], ports = ["22"]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 110, flow = "F14", name = "F14-Dashboard"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.hosts.monitor], ports = [tostring(var.monitor_ui_port)]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 120, flow = "F09", name = "F09-Updates"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.mgmt], dst = ["Internet"], ports = ["80", "443"]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 4096, flow = "F05", name = "Deny-Outbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "monitoring", dir = "Inbound", prio = 100, flow = "F08", name = "F08-Collect-Logs"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.dmz, var.subnet_cidrs.lan, var.subnet_cidrs.mgmt, var.nva_private_ip], dst = [var.hosts.monitor], ports = var.monitoring_ports
    },
    {
      nsg   = "monitoring", dir = "Inbound", prio = 110, flow = "F07", name = "F07-SSH-from-bastion"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.hosts.monitor], ports = ["22"]
    },
    {
      nsg   = "monitoring", dir = "Inbound", prio = 120, flow = "F14", name = "F14-Dashboard-from-bastion"
      proto = "Tcp", access = "Allow"
      src   = [var.hosts.bastion], dst = [var.hosts.monitor], ports = [tostring(var.monitor_ui_port)]
    },
    {
      nsg   = "monitoring", dir = "Inbound", prio = 4096, flow = "F05", name = "Deny-Inbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "monitoring", dir = "Outbound", prio = 120, flow = "F09", name = "F09-Updates"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.monitoring], dst = ["Internet"], ports = ["80", "443"]
    },
    {
      nsg   = "monitoring", dir = "Outbound", prio = 4096, flow = "F05", name = "Deny-Outbound"
      proto = "*", access = "Deny"
      src   = ["*"], dst = ["*"], ports = ["*"]
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 130, flow = "F10", name = "F10-Azure-DNS"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.dmz], dst = ["168.63.129.16"], ports = ["53"]
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 140, flow = "F10", name = "F10-Azure-Agent"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.dmz], dst = ["168.63.129.16"], ports = ["80", "32526"]
    },
    {
      nsg   = "dmz", dir = "Outbound", prio = 150, flow = "F10", name = "F10-Azure-IMDS"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.dmz], dst = ["169.254.169.254"], ports = ["80"]
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 130, flow = "F10", name = "F10-Azure-DNS"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.lan], dst = ["168.63.129.16"], ports = ["53"]
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 140, flow = "F10", name = "F10-Azure-Agent"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.lan], dst = ["168.63.129.16"], ports = ["80", "32526"]
    },
    {
      nsg   = "lan", dir = "Outbound", prio = 150, flow = "F10", name = "F10-Azure-IMDS"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.lan], dst = ["169.254.169.254"], ports = ["80"]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 130, flow = "F10", name = "F10-Azure-DNS"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.mgmt], dst = ["168.63.129.16"], ports = ["53"]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 140, flow = "F10", name = "F10-Azure-Agent"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.mgmt], dst = ["168.63.129.16"], ports = ["80", "32526"]
    },
    {
      nsg   = "mgmt", dir = "Outbound", prio = 150, flow = "F10", name = "F10-Azure-IMDS"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.mgmt], dst = ["169.254.169.254"], ports = ["80"]
    },
    {
      nsg   = "monitoring", dir = "Outbound", prio = 130, flow = "F10", name = "F10-Azure-DNS"
      proto = "*", access = "Allow"
      src   = [var.subnet_cidrs.monitoring], dst = ["168.63.129.16"], ports = ["53"]
    },
    {
      nsg   = "monitoring", dir = "Outbound", prio = 140, flow = "F10", name = "F10-Azure-Agent"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.monitoring], dst = ["168.63.129.16"], ports = ["80", "32526"]
    },
    {
      nsg   = "monitoring", dir = "Outbound", prio = 150, flow = "F10", name = "F10-Azure-IMDS"
      proto = "Tcp", access = "Allow"
      src   = [var.subnet_cidrs.monitoring], dst = ["169.254.169.254"], ports = ["80"]
    },
    ], length(var.admin_source_ips) > 0 ? [
    # F06 : INACCESSIBLE depuis Internet tant que M1 n'a pas passe de CIDR /32.
    {
      nsg   = "firewall", dir = "Inbound", prio = 105, flow = "F06", name = "F06-Admin-2222"
      proto = "Tcp", access = "Allow"
      src   = var.admin_source_ips, dst = [var.nva_private_ip], ports = ["2222"]
    },
    {
      nsg   = "mgmt", dir = "Inbound", prio = 100, flow = "F06", name = "F06-Admin-SSH-after-DNAT"
      proto = "Tcp", access = "Allow"
      src   = var.admin_source_ips, dst = [var.hosts.bastion], ports = ["22"]
    }
  ] : [])

  nsg_rules_map = {
    for r in local.nsg_rules :
    "${r.nsg}-${lower(r.dir)}-${r.prio}" => r
  }
}

resource "azurerm_network_security_group" "zone" {
  for_each = local.nsg_subnets

  name                = "nsg-${var.name_prefix}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "matrix" {
  for_each = local.nsg_rules_map

  name                        = each.value.name
  description                 = "Matrice Fxx: ${each.value.flow}"
  priority                    = each.value.prio
  direction                   = each.value.dir
  access                      = each.value.access
  protocol                    = each.value.proto
  source_port_range           = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.zone[each.value.nsg].name

  source_address_prefix        = length(each.value.src) == 1 ? each.value.src[0] : null
  source_address_prefixes      = length(each.value.src) > 1 ? each.value.src : null
  destination_address_prefix   = length(each.value.dst) == 1 ? each.value.dst[0] : null
  destination_address_prefixes = length(each.value.dst) > 1 ? each.value.dst : null
  destination_port_range       = length(each.value.ports) == 1 ? each.value.ports[0] : null
  destination_port_ranges      = length(each.value.ports) > 1 ? each.value.ports : null
}

# F01 : le port 80 n'est ouvert que pour rediriger vers HTTPS/443.
# Deux NSG car le NAT conserve l'IP cliente d'origine.
resource "azurerm_network_security_rule" "f01_firewall_web" {
  #checkov:skip=CKV_AZURE_160:F01 - port 80 requis uniquement pour redirection 80 vers 443
  name                        = "F01-Web-public"
  description                 = "F01 publication web via DNAT NVA"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = var.nva_private_ip
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.zone["firewall"].name
}

resource "azurerm_network_security_rule" "f01_dmz_web" {
  #checkov:skip=CKV_AZURE_160:F01 - DNAT sans SNAT, adresse cliente conservee par la NVA
  name                        = "F01-Web-from-public"
  description                 = "F01 apres DNAT - destination serveur web"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = var.hosts.web
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.zone["dmz"].name
}

resource "azurerm_subnet_network_security_group_association" "zone" {
  for_each                  = local.nsg_subnets
  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.zone[each.key].id
}

# F01: outbound packet after DNAT keeps the original Internet client source.
# Explicit allow required because the firewall subnet's default VNet outbound rule
# does not necessarily match forwarded packets with non-VNet source addresses.
resource "azurerm_network_security_rule" "f01_forwarded_to_web" {
  name                        = "F01-Forward-public-to-web"
  description                 = "F01 forwarded after DNAT; real client IP retained"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = var.hosts.web
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.zone["firewall"].name
}

# F06: after DNAT 2222 -> 22, outbound forwarded SSH retains admin IP.
resource "azurerm_network_security_rule" "f06_forwarded_to_bastion" {
  count                       = length(var.admin_source_ips) > 0 ? 1 : 0
  name                        = "F06-Forward-admin-to-bastion"
  description                 = "F06 forwarded after DNAT; admin IPs only"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = length(var.admin_source_ips) == 1 ? var.admin_source_ips[0] : null
  source_address_prefixes     = length(var.admin_source_ips) > 1 ? var.admin_source_ips : null
  destination_address_prefix  = var.hosts.bastion
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.zone["firewall"].name
}
