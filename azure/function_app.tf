# ── Azure Function App ────────────────────────────────────────────────────────

# Dedicated storage for Function App runtime (host bindings, logs, code)
resource "azurerm_storage_account" "function" {
  # checkov:skip=CKV_AZURE_206:LRS replication is sufficient for ephemeral function app runtime storage
  # checkov:skip=CKV2_AZURE_1:Y1 consumption plan requires network-accessible storage; no VNet integration available
  # checkov:skip=CKV2_AZURE_40:azurerm 3.x requires key auth; upgrade to 4.x to enforce SAS-less auth
  name                     = local.function_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Y1 consumption plan runs in Azure shared infrastructure and requires public storage access.
  # Switch to EP1+ (elastic premium) and set public_network_access_enabled = false to use VNet integration.
  public_network_access_enabled = true

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags
}

resource "azurerm_service_plan" "function" {
  name                = local.function_asp_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.function_app_sku_name

  tags = local.common_tags
}

resource "azurerm_linux_function_app" "main" {
  name                = local.function_app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  service_plan_id      = azurerm_service_plan.function.id
  storage_account_name = azurerm_storage_account.function.name

  # Use managed identity for storage access instead of access keys
  storage_uses_managed_identity = true

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    http2_enabled       = true

    application_stack {
      python_version = var.function_app_python_version
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    KEY_VAULT_URI            = azurerm_key_vault.main.vault_uri
  }

  tags = local.common_tags
}

# ── RBAC — grant Function App managed identity access to its storage ──────────

resource "azurerm_role_assignment" "function_storage_blob_owner" {
  principal_id                     = azurerm_linux_function_app.main.identity[0].principal_id
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.function.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "function_storage_queue_contributor" {
  principal_id                     = azurerm_linux_function_app.main.identity[0].principal_id
  role_definition_name             = "Storage Queue Data Contributor"
  scope                            = azurerm_storage_account.function.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "kv_function_secrets_user" {
  principal_id                     = azurerm_linux_function_app.main.identity[0].principal_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}
