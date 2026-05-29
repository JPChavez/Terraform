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

  # Data Factory
  adf_name = "${var.project_acronym}-adf-${var.environment}"

  # Event Hub
  eventhub_namespace_name = "${var.project_acronym}-evhns-${var.environment}"
  eventhub_name           = "${var.project_acronym}-evh-${var.environment}"

  # Synapse Analytics
  synapse_workspace_name = "${var.project_acronym}-syn-${var.environment}"
  synapse_storage_name   = lower("${var.project_acronym}synst${var.environment}")

  # Function App
  function_app_name     = "${var.project_acronym}-func-${var.environment}"
  function_asp_name     = "${var.project_acronym}-asp-func-${var.environment}"
  function_storage_name = lower("${var.project_acronym}funcst${var.environment}")

  # Cosmos DB
  cosmosdb_account_name = "${var.project_acronym}-cosmos-${var.environment}"

  # Logic Apps
  logic_app_name = "${var.project_acronym}-logic-${var.environment}"

  # AI Foundry (Azure Machine Learning Workspace)
  ai_foundry_name   = "${var.project_acronym}-mlw-${var.environment}"
  app_insights_name = "${var.project_acronym}-appi-${var.environment}"

  common_tags = {
    project     = var.project
    environment = var.environment
    region      = var.location
    owner       = var.owner
    managed_by  = "terraform"
  }
}
