resource "azurerm_resource_group" "main" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = var.tags
}

# ---------------- M1 ----------------
module "network" {
  source              = "../../modules/network"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  tags                = var.tags
}

module "mgmt" {
  source              = "../../modules/mgmt"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  subnet_id           = module.network.subnet_mgmt_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  private_ip_address  = "10.10.3.4"
  tags                = var.tags
}

# ---------------- M2 ----------------
module "firewall" {
  source              = "../../modules/firewall"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  subnet_id           = module.network.subnet_firewall_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  private_ip_address  = "10.10.0.4"
  tags                = var.tags
}

# ---------------- M3 ----------------
module "routing" {
  source              = "../../modules/routing"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  vnet_name           = module.network.vnet_name
  subnet_ids          = module.network.subnet_ids
  subnet_cidrs        = module.network.subnet_cidrs
  nva_private_ip      = module.firewall.nva_private_ip
  tags                = var.tags
}

# ---------------- M4 ----------------
module "dmz" {
  source              = "../../modules/dmz"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  subnet_id           = module.network.subnet_dmz_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  private_ip_address  = "10.10.1.4"
  tags                = var.tags
}

# ---------------- M5 ----------------
module "lan" {
  source              = "../../modules/lan"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  subnet_id           = module.network.subnet_lan_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  private_ip_address  = "10.10.2.4"
  tags                = var.tags
}

# ---------------- M6 ----------------
module "monitoring" {
  source              = "../../modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = var.name_prefix
  subnet_id           = module.network.subnet_monitoring_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  private_ip_address  = "10.10.4.4"
  tags                = var.tags
}
