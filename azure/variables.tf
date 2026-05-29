variable "tenant_id" {
  description = "Azure Active Directory Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, uat, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be dev, uat, or prod."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "terraform_operator_ip" {
  description = "Public IP of the machine running Terraform — added to Key Vault ip_rules to allow key management operations"
  type        = string
  default     = "189.217.80.179"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "Juan Pablo Chavez"
}

variable "project_acronym" {
  description = "Short acronym for the project used in resource names (e.g. 'jp' for JProject)"
  type        = string

  validation {
    condition     = length(var.project_acronym) <= 6 && can(regex("^[a-z0-9]+$", var.project_acronym))
    error_message = "project_acronym must be lowercase alphanumeric and max 6 characters."
  }
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "system_subnet_prefix" {
  description = "Address prefix for the system subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ── AKS ──────────────────────────────────────────────────────────────────────

variable "aks_kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.32"
}

variable "aks_system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "aks_system_vm_size" {
  description = "VM size for the AKS system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_user_min_count" {
  description = "Minimum number of nodes in the AKS user node pool"
  type        = number
  default     = 1
}

variable "aks_user_max_count" {
  description = "Maximum number of nodes in the AKS user node pool"
  type        = number
  default     = 3
}

variable "aks_user_vm_size" {
  description = "VM size for the AKS user node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

# ── ACR ───────────────────────────────────────────────────────────────────────

variable "acr_sku" {
  description = "SKU for the Azure Container Registry (Premium required for zone redundancy, data endpoints, quarantine, and geo-replication)"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

# ── Key Vault ─────────────────────────────────────────────────────────────────

variable "kv_sku" {
  description = "SKU for the Azure Key Vault"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.kv_sku)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

# ── Storage Account ───────────────────────────────────────────────────────────

variable "storage_account_tier" {
  description = "Performance tier for the Storage Account"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium."
  }
}

variable "storage_replication_type" {
  description = "Replication type for the Storage Account"
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "Invalid replication type."
  }
}

# ── AKS (extended) ────────────────────────────────────────────────────────────

variable "aks_private_cluster_enabled" {
  description = "Enable private cluster for AKS (API server not publicly accessible)"
  type        = bool
  default     = false
}

variable "aks_authorized_ip_ranges" {
  description = "Authorized IP ranges for AKS API server access (used when private_cluster_enabled = false)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── Private Endpoints ─────────────────────────────────────────────────────────

variable "pe_subnet_prefix" {
  description = "Address prefix for the private endpoints subnet"
  type        = string
  default     = "10.0.3.0/24"
}

# ── ACR (extended) ────────────────────────────────────────────────────────────

variable "acr_georeplica_location" {
  description = "Secondary region for ACR geo-replication (Premium SKU only, leave empty to disable)"
  type        = string
  default     = ""
}

# ── Event Hub ─────────────────────────────────────────────────────────────────

variable "eventhub_sku" {
  description = "SKU for the Event Hub namespace (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.eventhub_sku)
    error_message = "Event Hub SKU must be Basic, Standard, or Premium."
  }
}

variable "eventhub_capacity" {
  description = "Throughput units for the Event Hub namespace"
  type        = number
  default     = 1
}

variable "eventhub_message_retention_days" {
  description = "Message retention in days for Event Hub (1 for Basic, 1-7 for Standard, 1-90 for Premium)"
  type        = number
  default     = 1
}

# ── Synapse Analytics ─────────────────────────────────────────────────────────

variable "synapse_sql_admin_username" {
  description = "SQL administrator login name for the Synapse workspace"
  type        = string
  default     = "sqladmin"
}

# ── Function App ──────────────────────────────────────────────────────────────

variable "function_app_sku_name" {
  description = "SKU for the Function App service plan (Y1 = consumption, EP1/EP2/EP3 = elastic premium)"
  type        = string
  default     = "Y1"
}

variable "function_app_python_version" {
  description = "Python version for the Function App runtime stack"
  type        = string
  default     = "3.11"
}

# ── Cosmos DB ─────────────────────────────────────────────────────────────────

variable "cosmosdb_consistency_level" {
  description = "Default consistency level for the Cosmos DB account"
  type        = string
  default     = "Session"

  validation {
    condition     = contains(["Eventual", "ConsistentPrefix", "Session", "BoundedStaleness", "Strong"], var.cosmosdb_consistency_level)
    error_message = "Cosmos DB consistency level must be one of: Eventual, ConsistentPrefix, Session, BoundedStaleness, Strong."
  }
}

variable "cosmosdb_kind" {
  description = "API type for the Cosmos DB account (GlobalDocumentDB = Core SQL, MongoDB, Table)"
  type        = string
  default     = "GlobalDocumentDB"

  validation {
    condition     = contains(["GlobalDocumentDB", "MongoDB", "Parse", "Table"], var.cosmosdb_kind)
    error_message = "Cosmos DB kind must be one of: GlobalDocumentDB, MongoDB, Parse, Table."
  }
}
