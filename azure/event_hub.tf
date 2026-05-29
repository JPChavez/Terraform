# ── Azure Event Hub ───────────────────────────────────────────────────────────

resource "azurerm_eventhub_namespace" "main" {
  name                = local.eventhub_namespace_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.eventhub_sku
  capacity            = var.eventhub_capacity
  minimum_tls_version = "1.2"

  identity {
    type = "SystemAssigned"
  }

  # CKV_AZURE_93: deny public network access; restrict to trusted Azure services
  network_rulesets {
    default_action                 = "Deny"
    trusted_service_access_enabled = true

    # Allow Terraform operator for management operations
    ip_rule {
      action  = "Allow"
      ip_mask = var.terraform_operator_ip
    }
  }

  tags = local.common_tags
}

resource "azurerm_eventhub" "main" {
  name                = local.eventhub_name
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = 2
  message_retention   = var.eventhub_message_retention_days
}

resource "azurerm_eventhub_consumer_group" "main" {
  name                = "${local.prefix}-cg"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.main.name
  resource_group_name = azurerm_resource_group.main.name
}
