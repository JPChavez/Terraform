# ── Resource Group ────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

# ── AKS ──────────────────────────────────────────────────────────────────────

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_kube_config_command" {
  description = "Azure CLI command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

# ── ACR ───────────────────────────────────────────────────────────────────────

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL of the ACR"
  value       = azurerm_container_registry.main.login_server
}

# ── Key Vault ─────────────────────────────────────────────────────────────────

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# ── Storage Account ───────────────────────────────────────────────────────────

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob service endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

# ── Log Analytics ─────────────────────────────────────────────────────────────

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

# ── Data Factory ──────────────────────────────────────────────────────────────

output "data_factory_name" {
  description = "Name of the Azure Data Factory"
  value       = azurerm_data_factory.main.name
}

output "data_factory_id" {
  description = "Resource ID of the Azure Data Factory"
  value       = azurerm_data_factory.main.id
}

output "data_factory_principal_id" {
  description = "Principal ID of the Data Factory system-assigned managed identity"
  value       = azurerm_data_factory.main.identity[0].principal_id
}

# ── Event Hub ─────────────────────────────────────────────────────────────────

output "eventhub_namespace_name" {
  description = "Name of the Event Hub namespace"
  value       = azurerm_eventhub_namespace.main.name
}

output "eventhub_namespace_id" {
  description = "Resource ID of the Event Hub namespace"
  value       = azurerm_eventhub_namespace.main.id
}

output "eventhub_name" {
  description = "Name of the Event Hub"
  value       = azurerm_eventhub.main.name
}

# ── Synapse Analytics ─────────────────────────────────────────────────────────

output "synapse_workspace_name" {
  description = "Name of the Synapse Analytics workspace"
  value       = azurerm_synapse_workspace.main.name
}

output "synapse_workspace_id" {
  description = "Resource ID of the Synapse Analytics workspace"
  value       = azurerm_synapse_workspace.main.id
}

output "synapse_connectivity_endpoints" {
  description = "Connectivity endpoints for the Synapse workspace"
  value       = azurerm_synapse_workspace.main.connectivity_endpoints
}

# ── Function App ──────────────────────────────────────────────────────────────

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_id" {
  description = "Resource ID of the Function App"
  value       = azurerm_linux_function_app.main.id
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.main.default_hostname
}

# ── Cosmos DB ─────────────────────────────────────────────────────────────────

output "cosmosdb_account_name" {
  description = "Name of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmosdb_endpoint" {
  description = "Endpoint URI of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmosdb_id" {
  description = "Resource ID of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.id
}

# ── Logic Apps ────────────────────────────────────────────────────────────────

output "logic_app_name" {
  description = "Name of the Logic App workflow"
  value       = azurerm_logic_app_workflow.main.name
}

output "logic_app_id" {
  description = "Resource ID of the Logic App workflow"
  value       = azurerm_logic_app_workflow.main.id
}

output "logic_app_access_endpoint" {
  description = "Access endpoint URL for the Logic App workflow"
  value       = azurerm_logic_app_workflow.main.access_endpoint
}

# ── AI Foundry ────────────────────────────────────────────────────────────────

output "ai_foundry_workspace_name" {
  description = "Name of the AI Foundry (Machine Learning) workspace"
  value       = azurerm_machine_learning_workspace.main.name
}

output "ai_foundry_workspace_id" {
  description = "Resource ID of the AI Foundry workspace"
  value       = azurerm_machine_learning_workspace.main.id
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights (used by AI Foundry)"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}
