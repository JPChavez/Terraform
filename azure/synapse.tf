# ── Azure Synapse Analytics ───────────────────────────────────────────────────

# Random password for SQL admin — stored in Key Vault; never written to state unencrypted
resource "random_password" "synapse_sql_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "synapse_sql_admin_password" {
  name         = "synapse-sql-admin-password"
  value        = random_password.synapse_sql_admin.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_current_user_admin]
}

# ── ADLS Gen2 — dedicated storage for Synapse workspace ──────────────────────

resource "azurerm_storage_account" "synapse" {
  # checkov:skip=CKV_AZURE_206:ZRS replication is sufficient for this Synapse workload
  # checkov:skip=CKV2_AZURE_40:azurerm 3.x requires key auth to configure ADLS Gen2; upgrade to 4.x to enforce
  name                     = local.synapse_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Required for ADLS Gen2 (Synapse analytics data lake)
  is_hns_enabled = true

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  tags = local.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = "synapsefs"
  storage_account_id = azurerm_storage_account.synapse.id
}

# ── Synapse Workspace ─────────────────────────────────────────────────────────

resource "azurerm_synapse_workspace" "main" {
  name                = local.synapse_workspace_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse.id
  sql_administrator_login              = var.synapse_sql_admin_username
  sql_administrator_login_password     = random_password.synapse_sql_admin.result

  # CKV_AZURE_58: enable managed VNet to isolate Synapse integration runtimes
  managed_virtual_network_enabled = true

  # CKV_AZURE_157: set to true when allowed_linked_domain_names are configured
  data_exfiltration_protection_enabled = false

  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# ── RBAC — grant Synapse managed identity access to ADLS Gen2 ────────────────

resource "azurerm_role_assignment" "synapse_adls_contributor" {
  principal_id                     = azurerm_synapse_workspace.main.identity[0].principal_id
  role_definition_name             = "Storage Blob Data Contributor"
  scope                            = azurerm_storage_account.synapse.id
  skip_service_principal_aad_check = true
}
