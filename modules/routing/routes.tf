# Les UDR /24 inter-zones priment sur la route systeme Azure VNetLocal /16.
# Ne PAS associer d'UDR au subnet du firewall/NVA : evite les boucles.
locals {
  routed_zones = {
    for zone in ["dmz", "lan", "mgmt", "monitoring"] : zone => {
      subnet_id = var.subnet_ids[zone]
      other_cidrs = {
        for other in ["dmz", "lan", "mgmt", "monitoring"] :
        other => var.subnet_cidrs[other] if other != zone
      }
    }
  }
}

resource "azurerm_route_table" "zone" {
  for_each = local.routed_zones

  name                          = "rt-${var.name_prefix}-${each.key}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-via-nva"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.nva_private_ip
  }

  dynamic "route" {
    for_each = each.value.other_cidrs
    content {
      name                   = "${route.key}-via-nva"
      address_prefix         = route.value
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.nva_private_ip
    }
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "zone" {
  for_each       = local.routed_zones
  subnet_id      = each.value.subnet_id
  route_table_id = azurerm_route_table.zone[each.key].id
}
