locals {
  # Naming convention: <project_acronym>-<resource-abbreviation>-<environment>
  # Example: jp-kv-dev, jp-aks-dev, jp-rg-dev
  prefix = "${var.project_acronym}-${var.environment}"

  resource_group_name = "${var.project_acronym}-rg-${var.environment}"

  # AKS
  aks_cluster_name = "${var.project_acronym}-aks-${var.environment}"
  aks_dns_prefix   = "${var.project_acronym}aks${var.environment}"
  aks_node_rg_name = "${var.project_acronym}-rg-nodes-${var.environment}"

  # ACR — must be alphanumeric only, globally unique
  acr_name = lower("${var.project_acronym}acr${var.environment}")

  # Key Vault — max 24 chars, globally unique (suffix with first 4 chars of subscription ID)
  kv_name = lower("${var.project_acronym}-kv-${var.environment}-${substr(var.subscription_id, 0, 4)}")

  # Storage Account — max 24 chars, lowercase alphanumeric only, globally unique
  storage_account_name = lower("${var.project_acronym}st${var.environment}")

  # Network
  vnet_name   = "${var.project_acronym}-vnet-${var.environment}"
  snet_aks    = "${var.project_acronym}-snet-aks-${var.environment}"
  snet_system = "${var.project_acronym}-snet-system-${var.environment}"
  snet_pe     = "${var.project_acronym}-snet-pe-${var.environment}"

  common_tags = {
    project     = var.project
    environment = var.environment
    region      = var.location
    owner       = var.owner
    managed_by  = "terraform"
  }
}
