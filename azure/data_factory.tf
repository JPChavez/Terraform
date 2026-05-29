# ── Azure Data Factory ────────────────────────────────────────────────────────

resource "azurerm_data_factory" "main" {
  name                = local.adf_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # System-assigned managed identity — used for connecting to linked services
  identity {
    type = "SystemAssigned"
  }

  # CKV_AZURE_103: disable public network access; use private endpoint for portal/runtime
  public_network_enabled = false

  tags = local.common_tags
}

# ── RBAC — grant ADF managed identity access to linked services ───────────────

resource "azurerm_role_assignment" "kv_adf_secrets_user" {
  principal_id                     = azurerm_data_factory.main.identity[0].principal_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "storage_adf_blob_contributor" {
  principal_id                     = azurerm_data_factory.main.identity[0].principal_id
  role_definition_name             = "Storage Blob Data Contributor"
  scope                            = azurerm_storage_account.main.id
  skip_service_principal_aad_check = true
}
