resource "azurerm_key_vault" "main" {
  name                = local.kv_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = var.tenant_id
  sku_name            = var.kv_sku

  # Security best practices
  # enable_rbac_authorization is deprecated in the IDE but still functional in azurerm ~> 3.110
  # It is required here so that role assignments (azurerm_role_assignment) work correctly
  enable_rbac_authorization       = true
  soft_delete_retention_days      = 90
  purge_protection_enabled        = true
  # public_network_access_enabled = true is required for ip_rules to work.
  # Access is restricted via network_acls (default_action = Deny + explicit ip_rules).
  # Private endpoint provides VNet-level connectivity.
  public_network_access_enabled = true

  # CKV_AZURE_109: deny all traffic by default; allow only from approved sources
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.system.id]
    ip_rules                   = [var.terraform_operator_ip]  # Terraform operator IP for key management
  }

  # CKV2_AZURE_32: private endpoint connectivity is provided in private_endpoints.tf

  tags = local.common_tags
}

# Grant the pipeline / current caller admin rights to manage secrets
resource "azurerm_role_assignment" "kv_current_user_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.main.id
}

# Grant AKS managed identity read access to secrets
resource "azurerm_role_assignment" "kv_aks_secrets_user" {
  principal_id                     = azurerm_kubernetes_cluster.main.identity[0].principal_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}
