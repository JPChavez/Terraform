data "azurerm_resource_group" "aks_nodes" {
  name = var.aks_node_rg
}

resource "azurerm_public_ip" "aiagents" {
  name                = "aiagents-ip"
  resource_group_name = data.azurerm_resource_group.aks_nodes.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label

  tags = {
    project    = "AIAgentsPortal"
    managed_by = "terraform"
  }
}
