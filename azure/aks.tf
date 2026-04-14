resource "azurerm_kubernetes_cluster" "main" {
  name                = local.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.aks_dns_prefix
  kubernetes_version  = var.aks_kubernetes_version
  node_resource_group = local.aks_node_rg_name

  #checkov:skip=CKV_AZURE_115:Private cluster conflicts with api_server_access_profile; API server is protected by authorized IP ranges in non-private environments (see aks-gotchas.md)
  #checkov:skip=CKV_AZURE_226:Ephemeral OS disk cannot fit on Standard_D2s_v3 (cache ~50GB < 128GB required); Managed disk used per known AKS gotcha

  # Security best practices
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true
  azure_policy_enabled              = true                                # CKV_AZURE_116
  private_cluster_enabled           = var.aks_private_cluster_enabled     # CKV_AZURE_115
  disk_encryption_set_id            = azurerm_disk_encryption_set.main.id # CKV_AZURE_117
  sku_tier                          = "Standard"                          # CKV_AZURE_170
  automatic_channel_upgrade         = "stable"                            # CKV_AZURE_171

  identity {
    type = "SystemAssigned"
  }

  # CKV_AZURE_6: restrict API server access when cluster is not private
  dynamic "api_server_access_profile" {
    for_each = var.aks_private_cluster_enabled ? [] : [1]
    content {
      authorized_ip_ranges = var.aks_authorized_ip_ranges
    }
  }

  # CKV_AZURE_172: Key Vault secrets provider with rotation
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # System node pool — dedicated to Kubernetes system components
  default_node_pool {
    name                         = "system"
    node_count                   = var.aks_system_node_count
    vm_size                      = var.aks_system_vm_size
    vnet_subnet_id               = azurerm_subnet.aks.id
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed" # Standard_D2s_v3 cache (~50GB) cannot fit 128GB ephemeral OS disk
    max_pods                     = 110       # CKV_AZURE_168
    enable_host_encryption       = true      # CKV_AZURE_227

    upgrade_settings {
      max_surge = "10%"
    }
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    # Must not overlap with vnet (10.0.0.0/16) or any subnets
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  tags = local.common_tags
}

# User node pool — for application workloads with autoscaling
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                   = "user"
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.main.id
  vm_size                = var.aks_user_vm_size
  vnet_subnet_id         = azurerm_subnet.aks.id
  os_disk_type           = "Managed" # D4s_v3 cache (~100GB) may not fit 128GB ephemeral; use Managed for reliability
  mode                   = "User"
  max_pods               = 110  # CKV_AZURE_168
  enable_host_encryption = true # CKV_AZURE_227

  enable_auto_scaling = true
  min_count           = var.aks_user_min_count
  max_count           = var.aks_user_max_count

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.common_tags
}

# ── Log Analytics Workspace (required for OMS agent + Defender) ───────────────

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}
