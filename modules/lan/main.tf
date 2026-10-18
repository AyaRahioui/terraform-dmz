# TODO (M5) : implémenter ce module.
# Règles : voir README.md à la racine. Ne pas créer de Resource Group ni de VNet.
# Quand une vraie ressource existe, remplacer la valeur placeholder dans outputs.tf
# par la référence réelle (ex: azurerm_linux_virtual_machine.nva.id).
# vm-app (API minimale) + vm-db (PostgreSQL, pg_hba.conf, moindre privilège).


locals {
  app_ip = coalesce(var.private_ip_address, var.app_private_ip_address)
  db_ip  = var.db_private_ip_address
}

resource "random_password" "app_db" {
  length  = 24
  special = false
}

# ---------- vm-app ----------
resource "azurerm_network_interface" "app" {
  name                = "nic-${var.name_prefix}-app"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.app_ip
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-${var.name_prefix}-app"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(join("\n", [
    "#!/bin/bash",
    "export DB_HOST=${local.db_ip}",
    "export DB_PASSWORD=${random_password.app_db.result}",
    "export DMZ_IP=${var.dmz_ip_address}",
    "export BASTION_IP=${var.bastion_ip_address}",
    file("${path.module}/scripts/install-app.sh"),
  ]))
}

# ---------- vm-db ----------
resource "azurerm_network_interface" "db" {
  name                = "nic-${var.name_prefix}-db"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.db_ip
  }
}

resource "azurerm_linux_virtual_machine" "db" {
  name                            = "vm-${var.name_prefix}-db"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.db.id]
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(join("\n", [
    "#!/bin/bash",
    "export APP_IP=${local.app_ip}",
    "export DB_PASSWORD=${random_password.app_db.result}",
    "export DB_IP=${local.db_ip}",
    "export BASTION_IP=${var.bastion_ip_address}",
    file("${path.module}/scripts/install-postgresql.sh"),
    file("${path.module}/scripts/configure-db.sh"),
  ]))
}