mock_provider "azurerm" {}

run "routing_basic" {
  command = plan

  variables {
    resource_group_name = "rg-test"
    location            = "germanywestcentral"
    name_prefix         = "test"
    vnet_name           = "vnet-test"
    nva_private_ip      = "10.10.0.4"
    subnet_ids = {
      firewall   = "/subscriptions/0/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/firewall"
      dmz        = "/subscriptions/0/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/dmz"
      lan        = "/subscriptions/0/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/lan"
      mgmt       = "/subscriptions/0/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/mgmt"
      monitoring = "/subscriptions/0/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/monitoring"
    }
    subnet_cidrs = {
      firewall   = "10.10.0.0/24"
      dmz        = "10.10.1.0/24"
      lan        = "10.10.2.0/24"
      mgmt       = "10.10.3.0/24"
      monitoring = "10.10.4.0/24"
    }
  }
}
