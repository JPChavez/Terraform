resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku

  # Security best practices
  admin_enabled                 = false
  public_network_access_enabled = false                                    # CKV_AZURE_139: always disable public access
  zone_redundancy_enabled       = true # CKV_AZURE_233 (requires Premium SKU at deploy time)
  data_endpoint_enabled         = true # CKV_AZURE_237 (requires Premium SKU at deploy time)
  quarantine_policy_enabled     = true # CKV_AZURE_166 (requires Premium SKU at deploy time)
  retention_policy {
    days    = 7     # CKV_AZURE_167: cleanup untagged manifests
    enabled = true
  }

  trust_policy {
    enabled = true  # CKV_AZURE_164: signed/trusted images
  }

  identity {
    type = "SystemAssigned"
  }

  network_rule_set {
    default_action = "Deny"
  }

  # CKV_AZURE_165: geo-replication — only enabled when acr_georeplica_location is set.
  # Zone redundancy is only applied in regions that support it (e.g. eastus).
  dynamic "georeplications" {
    for_each = var.acr_georeplica_location != "" ? [var.acr_georeplica_location] : []
    content {
      location                = georeplications.value
      zone_redundancy_enabled = georeplications.value == "eastus" ? true : false
    }
  }

  tags = local.common_tags
}

# Grant AKS kubelet identity pull access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
