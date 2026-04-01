# User-assigned identity for storage CMK
resource "azurerm_user_assigned_identity" "storage" {
  name                = "id-storage-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

# Key Vault key for AKS disk encryption — RSA-HSM satisfies CKV_AZURE_112
resource "azurerm_key_vault_key" "disk_encryption" {
  name            = "key-des-${local.prefix}"
  key_vault_id    = azurerm_key_vault.main.id
  key_type        = "RSA-HSM"
  key_size        = 4096
  key_opts        = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  expiration_date = "2027-01-01T00:00:00Z"
  depends_on      = [azurerm_role_assignment.kv_current_user_admin]
  tags            = local.common_tags
}

# Key Vault key for Storage CMK — RSA-HSM satisfies CKV_AZURE_112
resource "azurerm_key_vault_key" "storage" {
  name            = "key-storage-${local.prefix}"
  key_vault_id    = azurerm_key_vault.main.id
  key_type        = "RSA-HSM"
  key_size        = 4096
  key_opts        = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  expiration_date = "2027-01-01T00:00:00Z"
  depends_on      = [azurerm_role_assignment.kv_current_user_admin]
  tags            = local.common_tags
}

# Disk Encryption Set for AKS
resource "azurerm_disk_encryption_set" "main" {
  name                      = "des-${local.prefix}"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  # auto_key_rotation_enabled requires a versionless key ID
  key_vault_key_id          = azurerm_key_vault_key.disk_encryption.versionless_id
  auto_key_rotation_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant DES managed identity access to Key Vault
resource "azurerm_role_assignment" "des_kv_crypto" {
  principal_id         = azurerm_disk_encryption_set.main.identity[0].principal_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  scope                = azurerm_key_vault.main.id
}

# Grant storage user-assigned identity access to Key Vault for CMK
resource "azurerm_role_assignment" "storage_identity_kv_crypto" {
  principal_id         = azurerm_user_assigned_identity.storage.principal_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  scope                = azurerm_key_vault.main.id
}
