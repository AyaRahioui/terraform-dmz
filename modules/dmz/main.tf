# ---------------------------------------------------------------------------
# Module dmz (M4) - vm-web: reverse proxy Nginx + TLS + WAF (ModSecurity/CRS)
# ---------------------------------------------------------------------------

# 1. Network card of vm-web, plugged into the DMZ subnet.
#    No public IP: Internet visitors reach vm-web through the NVA (DNAT).
resource "azurerm_network_interface" "web" {
  name                = "nic-${var.name_prefix}-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.private_ip_address
  }
}

# 2. The VM itself (Ubuntu 24.04 LTS).
resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-${var.name_prefix}-web"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web.id]
  tags                  = var.tags

  # SSH key only, never a password
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # No VM extensions: everything is configured by the setup script below
  allow_extension_operations = false

  os_disk {
    name                 = "osdisk-${var.name_prefix}-web"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # 3. Setup script run once at first boot (by cloud-init).
  #    templatefile() = file() + replaces the ${...} placeholders with our variables.
  custom_data = base64encode(templatefile("${path.module}/scripts/setup-web.sh", {
    backend_ip   = var.backend_ip
    backend_port = var.backend_port
    bastion_ip   = var.bastion_ip
  }))
}
