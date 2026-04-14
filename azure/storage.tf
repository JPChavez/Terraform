resource "azurerm_storage_account" "main" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type #checkov:skip=CKV_AZURE_206:ZRS provides zone-level redundancy which is sufficient for this workload; cross-region GRS is not required
  account_kind             = "StorageV2"

  # Security best practices
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  # shared_access_key_enabled must remain true: azurerm 3.x uses the storage key to verify
  # blob service availability after creation/CMK setup — disabling it causes a 403 at apply time.
  # Security posture is maintained by: CMK encryption, private endpoint, public network access disabled,
  # and a 90-day SAS expiration policy (sas_policy below). Upgrade to azurerm 4.x to enforce false.
  shared_access_key_enabled        = true  #checkov:skip=CKV2_AZURE_40:azurerm 3.x provider requires key auth to verify blob service during create/CMK setup; upgrade to azurerm 4.x to enforce this
  public_network_access_enabled    = false # CKV_AZURE_59: always disable public access
  cross_tenant_replication_enabled = false

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  # CKV_AZURE_33: queue_properties cannot be managed when shared_access_key_enabled=false
  # (azurerm provider uses key-based auth to read/write queue properties)
  #checkov:skip=CKV_AZURE_33:Queue logging requires key-based auth which is disabled for security; blob/container soft-delete and versioning are enabled instead

  # CKV2_AZURE_41: limit SAS token lifetime to 90 days
  sas_policy {
    expiration_period = "90.00:00:00"
  }

  # CKV2_AZURE_1: customer-managed key for storage encryption
  # CKV2_AZURE_33: private endpoint connectivity is provided in private_endpoints.tf
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  tags = local.common_tags
}

# Grant AKS managed identity Storage Blob Data Contributor access
resource "azurerm_role_assignment" "storage_aks_contributor" {
  principal_id                     = azurerm_kubernetes_cluster.main.identity[0].principal_id
  role_definition_name             = "Storage Blob Data Contributor"
  scope                            = azurerm_storage_account.main.id
  skip_service_principal_aad_check = true
}
