mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-test"
  location            = "germanywestcentral"
  name_prefix         = "test"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-x"
  # Clé publique factice mais bien formée (32 octets nuls) : le provider décode la clé.
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA test"
}

run "firewall_basic" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.nva.name == "vm-test-nva"
    error_message = "Nom attendu : vm-<prefix>-nva."
  }

  assert {
    condition     = azurerm_network_interface.nva.ip_forwarding_enabled
    error_message = "L'IP forwarding doit être activé sur la NIC primaire."
  }

  assert {
    condition     = azurerm_linux_virtual_machine.nva.disable_password_authentication
    error_message = "Authentification par mot de passe interdite."
  }

  assert {
    condition     = azurerm_public_ip.nva.sku == "Standard" && azurerm_public_ip.nva.allocation_method == "Static"
    error_message = "IP publique Standard statique attendue (DNAT)."
  }
}

run "firewall_static_ip_contract" {
  command = plan

  variables {
    private_ip_address = "10.10.0.4"
  }

  assert {
    condition     = output.nva_private_ip == "10.10.0.4"
    error_message = "nva_private_ip doit valoir l'IP du plan (next hop des UDR de M3) dès le plan."
  }

  assert {
    condition     = azurerm_network_interface.nva.ip_configuration[0].private_ip_address_allocation == "Static"
    error_message = "IP fournie => allocation statique."
  }
}

run "firewall_two_nics" {
  command = plan

  assert {
    condition     = length(azurerm_network_interface.trust) == 1 && azurerm_network_interface.trust[0].ip_forwarding_enabled
    error_message = "La NIC trust doit exister avec IP forwarding."
  }

  assert {
    condition     = length(azurerm_linux_virtual_machine.nva.network_interface_ids) == 2
    error_message = "La NVA doit avoir 2 NIC."
  }
}

run "firewall_single_nic" {
  command = plan

  variables {
    enable_trust_nic = false
  }

  assert {
    condition     = length(azurerm_network_interface.trust) == 0 && length(azurerm_linux_virtual_machine.nva.network_interface_ids) == 1
    error_message = "enable_trust_nic = false => une seule NIC."
  }
}

run "nftables_anti_lockout_and_policy" {
  command = plan

  assert {
    condition     = can(regex("policy drop;\\s*ip saddr \\$MGMT_NET tcp dport 22 accept", output.nftables_ruleset))
    error_message = "ANTI-LOCKOUT : la 1re règle de la chaîne input doit autoriser SSH depuis mgmt."
  }

  assert {
    condition     = strcontains(output.nftables_ruleset, "define MGMT_NET  = 10.10.3.0/24")
    error_message = "Le subnet mgmt du plan d'adressage doit être utilisé."
  }

  assert {
    condition     = length(regexall("policy drop;", output.nftables_ruleset)) == 2
    error_message = "input et forward doivent être en policy drop."
  }

  assert {
    condition     = strcontains(output.nftables_ruleset, "dnat to $WEB_IP") && strcontains(output.nftables_ruleset, "define WEB_IP    = 10.10.1.4")
    error_message = "Le DNAT doit cibler vm-web (10.10.1.4)."
  }

  assert {
    condition     = strcontains(output.nftables_ruleset, "define DNAT_TCP   = { 80, 443 }")
    error_message = "Ports publiés par défaut : 80 et 443."
  }
}

run "f06_disabled_by_default_f14_present" {
  command = plan

  assert {
    condition     = !strcontains(output.nftables_ruleset, "F06")
    error_message = "Sans admin_source_ips, aucun DNAT SSH ne doit être ouvert depuis Internet."
  }

  assert {
    condition     = strcontains(output.nftables_ruleset, "ip saddr $BASTION_IP ip daddr $MON_IP tcp dport $UI_TCP accept")
    error_message = "F14 : le bastion doit pouvoir joindre Grafana."
  }
}

run "f06_admin_dnat_to_bastion" {
  command = plan

  variables {
    admin_source_ips = ["203.0.113.10/32"]
  }

  assert {
    condition     = strcontains(output.nftables_ruleset, "define ADMIN_IPS  = { 203.0.113.10/32 }")
    error_message = "Les IP d'admin doivent être injectées dans le ruleset."
  }

  assert {
    condition     = strcontains(output.nftables_ruleset, "tcp dport 2222 dnat to $BASTION_IP:22")
    error_message = "F06 : NVA:2222 doit être redirigé vers bastion:22."
  }
}

run "rejects_admin_ip_not_32" {
  command = plan

  variables {
    admin_source_ips = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_source_ips]
}

run "custom_data_is_safe" {
  command = plan

  assert {
    condition     = strcontains(base64decode(azurerm_linux_virtual_machine.nva.custom_data), "nft -c -f /etc/nftables.conf.new")
    error_message = "Le script doit valider la syntaxe nftables avant de l'appliquer."
  }

  assert {
    condition     = !strcontains(base64decode(azurerm_linux_virtual_machine.nva.custom_data), "\r")
    error_message = "custom_data ne doit contenir aucun CRLF."
  }

  assert {
    condition     = startswith(base64decode(azurerm_linux_virtual_machine.nva.custom_data), "#!/bin/bash\n")
    error_message = "custom_data doit commencer par un shebang bash."
  }
}

run "rejects_invalid_ip" {
  command = plan

  variables {
    private_ip_address = "10.10.0.999"
  }

  expect_failures = [var.private_ip_address]
}

run "rejects_invalid_port" {
  command = plan

  variables {
    dnat_tcp_ports = [80, 70000]
  }

  expect_failures = [azurerm_linux_virtual_machine.nva]
}
