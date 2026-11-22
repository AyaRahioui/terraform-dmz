# Module firewall (M2) : NVA Linux 2 NIC, IP forwarding, nftables, anti-lockout.
#
#   Internet ──► pip-<prefix>-nva ──► eth0 "untrust" (10.10.0.4, next hop des UDR)
#                                       │  nftables : DNAT 80/443 -> vm-web, filtrage, SNAT sortie
#   VNet 10.10.0.0/16 ◄──────────────── eth1 "trust" (route 10.10.0.0/16 via passerelle Azure)
#
# Pas de Resource Group, pas de VNet, pas de NSG ici (NSG/UDR = M3).

locals {
  nva_name = "vm-${var.name_prefix}-nva"

  # Tous les ports, pour vérifier qu'ils sont valides (précondition sur la VM).
  all_ports = concat(
    var.dnat_tcp_ports, var.app_tcp_ports, var.monitoring_scrape_tcp_ports,
    var.monitoring_ingest_tcp_ports, var.egress_tcp_ports, var.egress_udp_ports,
    var.monitoring_ui_tcp_ports, [var.admin_ssh_dnat_port],
  )
  all_cidrs = [
    var.vnet_cidr, var.firewall_subnet_cidr, var.dmz_subnet_cidr,
    var.lan_subnet_cidr, var.mgmt_subnet_cidr, var.monitoring_subnet_cidr,
  ]

  # IP sur laquelle Azure livre le trafic de l'IP publique (= IP de eth0).
  # Si l'IP est dynamique, on ne la connaît pas avant le boot : le script la lit sur eth0.
  nva_ip_for_rules = var.private_ip_address == null ? "" : var.private_ip_address

  nftables_conf = templatefile("${path.module}/scripts/nftables.conf", {
    vnet_cidr           = var.vnet_cidr
    dmz_cidr            = var.dmz_subnet_cidr
    lan_cidr            = var.lan_subnet_cidr
    mgmt_cidr           = var.mgmt_subnet_cidr
    monitoring_cidr     = var.monitoring_subnet_cidr
    web_ip              = var.web_private_ip
    app_ip              = var.app_private_ip
    monitoring_ip       = var.monitoring_private_ip
    dnat_tcp_ports      = join(", ", var.dnat_tcp_ports)
    app_tcp_ports       = join(", ", var.app_tcp_ports)
    scrape_tcp_ports    = join(", ", var.monitoring_scrape_tcp_ports)
    ingest_tcp_ports    = join(", ", var.monitoring_ingest_tcp_ports)
    egress_tcp_ports    = join(", ", var.egress_tcp_ports)
    egress_udp_ports    = join(", ", var.egress_udp_ports)
    ui_tcp_ports        = join(", ", var.monitoring_ui_tcp_ports)
    bastion_ip          = var.bastion_private_ip
    admin_source_ips    = join(", ", var.admin_source_ips)
    admin_ssh_dnat_port = var.admin_ssh_dnat_port
    untrust_interface   = "eth0"
    nva_ip_placeholder  = "__NVA_IP__"
  })

  # replace() : protège contre les fins de ligne CRLF (checkout Windows avec autocrlf=true),
  # sinon "#!/bin/bash\r" fait échouer cloud-init.
  custom_data = replace(templatefile("${path.module}/scripts/install-firewall.sh", {
    nftables_conf     = local.nftables_conf
    nva_ip            = local.nva_ip_for_rules
    safe_apply_script = file("${path.module}/scripts/nft-safe-apply.sh")
    trust_nic_enabled = var.enable_trust_nic
    vnet_cidr         = var.vnet_cidr
    trust_gateway     = cidrhost(coalesce(var.trust_subnet_cidr, var.firewall_subnet_cidr), 1)
  }), "\r\n", "\n")
}

resource "azurerm_public_ip" "nva" {
  name                = "pip-${var.name_prefix}-nva"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# NIC primaire "untrust" (eth0) : IP publique + IP du plan (10.10.0.4) = next hop des UDR.
resource "azurerm_network_interface" "nva" {
  #checkov:skip=CKV_AZURE_118:Une NVA doit router : IP forwarding obligatoire.
  #checkov:skip=CKV_AZURE_119:IP publique nécessaire pour le DNAT vers la DMZ ; filtrée par nftables + NSG (M3).
  name                  = "nic-${var.name_prefix}-nva"
  location              = var.location
  resource_group_name   = var.resource_group_name
  ip_forwarding_enabled = true
  tags                  = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.private_ip_address
    public_ip_address_id          = azurerm_public_ip.nva.id
  }
}

# NIC secondaire "trust" (eth1) : sortie vers les subnets internes.
resource "azurerm_network_interface" "trust" {
  #checkov:skip=CKV_AZURE_118:Une NVA doit router : IP forwarding obligatoire.
  count = var.enable_trust_nic ? 1 : 0

  name                  = "nic-${var.name_prefix}-nva-trust"
  location              = var.location
  resource_group_name   = var.resource_group_name
  ip_forwarding_enabled = true
  tags                  = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = coalesce(var.trust_subnet_id, var.subnet_id)
    private_ip_address_allocation = var.trust_private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.trust_private_ip_address
  }
}

resource "azurerm_linux_virtual_machine" "nva" {
  name                            = local.nva_name
  computer_name                   = local.nva_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  allow_extension_operations      = var.allow_extension_operations
  # L'ordre compte : la 1re NIC est la primaire (eth0).
  network_interface_ids = concat([azurerm_network_interface.nva.id], azurerm_network_interface.trust[*].id)
  custom_data           = base64encode(local.custom_data)
  tags                  = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.name_prefix}-nva"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Disque de boot diag managé : indispensable pour la Serial Console (dernier recours si lockout).
  boot_diagnostics {}

  lifecycle {
    precondition {
      condition     = alltrue([for p in local.all_ports : p >= 1 && p <= 65535 && floor(p) == p])
      error_message = "Tous les ports doivent être des entiers entre 1 et 65535."
    }
    precondition {
      condition = alltrue([
        length(var.dnat_tcp_ports) > 0, length(var.app_tcp_ports) > 0,
        length(var.monitoring_scrape_tcp_ports) > 0, length(var.monitoring_ingest_tcp_ports) > 0,
        length(var.egress_tcp_ports) > 0, length(var.egress_udp_ports) > 0,
        length(var.monitoring_ui_tcp_ports) > 0,
      ])
      error_message = "Les listes de ports ne peuvent pas être vides (syntaxe nftables)."
    }
    precondition {
      condition     = alltrue([for c in local.all_cidrs : can(cidrnetmask(c))])
      error_message = "Un des CIDR du plan d'adressage est invalide."
    }
  }
}
