# ── Azure AI Foundry (Machine Learning Workspace) ─────────────────────────────
# Azure AI Foundry is built on Azure Machine Learning. The ML workspace serves
# as the hub for AI projects, model deployments, and prompt flows.
# Azure OpenAI / AI Services are deployed as separate azurerm_cognitive_account
# resources and linked to this workspace as connections.

resource "azurerm_application_insights" "main" {
  name                = local.app_insights_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

  # Route telemetry to the existing Log Analytics workspace
  workspace_id = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags
}

resource "azurerm_machine_learning_workspace" "main" {
  # checkov:skip=CKV_AZURE_145:CMK for ML workspace requires additional Key Vault key and DES; not yet provisioned in this environment
  name                = local.ai_foundry_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Required dependencies
  application_insights_id = azurerm_application_insights.main.id
  key_vault_id            = azurerm_key_vault.main.id
  storage_account_id      = azurerm_storage_account.main.id
  container_registry_id   = azurerm_container_registry.main.id

  # CKV_AZURE_144: disable public network access; use private endpoint for studio access
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# ── RBAC — grant AI Foundry managed identity access to supporting services ────

resource "azurerm_role_assignment" "kv_aifoundry_secrets_user" {
  principal_id                     = azurerm_machine_learning_workspace.main.identity[0].principal_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "storage_aifoundry_blob_contributor" {
  principal_id                     = azurerm_machine_learning_workspace.main.identity[0].principal_id
  role_definition_name             = "Storage Blob Data Contributor"
  scope                            = azurerm_storage_account.main.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr_aifoundry_pull" {
  principal_id                     = azurerm_machine_learning_workspace.main.identity[0].principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
