# ── Azure Cosmos DB ───────────────────────────────────────────────────────────

resource "azurerm_cosmosdb_account" "main" {
  name                = local.cosmosdb_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = var.cosmosdb_kind

  consistency_policy {
    consistency_level = var.cosmosdb_consistency_level
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # Disable all public access — private endpoint provides connectivity
  public_network_access_enabled = false

  # Disable key-based auth — all access via managed identity / RBAC
  local_authentication_disabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}
