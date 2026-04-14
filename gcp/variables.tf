variable "gcp_project_id" {
  description = "GCP Project ID where resources will be deployed"
  type        = string
}

variable "region" {
  description = "GCP region for resource deployment"
  type        = string
  default     = "us-east1"
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

variable "project" {
  description = "Project name used for resource labels"
  type        = string
}

variable "project_acronym" {
  description = "Short acronym for the project used in resource names (e.g. 'jp' for JProject)"
  type        = string

  validation {
    condition     = length(var.project_acronym) <= 6 && can(regex("^[a-z0-9]+$", var.project_acronym))
    error_message = "project_acronym must be lowercase alphanumeric and max 6 characters."
  }
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "Juan Pablo Chavez"
}

variable "terraform_operator_ip" {
  description = "Public IP of the machine running Terraform — used in authorized network rules"
  type        = string
  default     = "189.217.80.179"
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "Primary CIDR for the GKE nodes subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "system_subnet_cidr" {
  description = "CIDR for the system/tooling subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pod IP allocation (alias range)"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE service IP allocation (alias range)"
  type        = string
  default     = "10.8.0.0/20"
}

variable "master_cidr" {
  description = "CIDR for the GKE control plane (/28 required by GCP)"
  type        = string
  default     = "172.16.0.0/28"
}

# ── GKE ──────────────────────────────────────────────────────────────────────

variable "gke_kubernetes_version" {
  description = "Minimum Kubernetes version for the GKE cluster"
  type        = string
  default     = "1.32"
}

variable "gke_system_node_count" {
  description = "Number of nodes in the GKE system node pool (per zone)"
  type        = number
  default     = 1
}

variable "gke_system_machine_type" {
  description = "Machine type for the GKE system node pool (Azure D2s_v3 equivalent: n2-standard-2)"
  type        = string
  default     = "n2-standard-2"
}

variable "gke_user_min_count" {
  description = "Minimum number of nodes in the GKE user node pool (per zone)"
  type        = number
  default     = 1
}

variable "gke_user_max_count" {
  description = "Maximum number of nodes in the GKE user node pool (per zone)"
  type        = number
  default     = 3
}

variable "gke_user_machine_type" {
  description = "Machine type for the GKE user node pool (Azure D4s_v3 equivalent: n2-standard-4)"
  type        = string
  default     = "n2-standard-4"
}

variable "gke_node_locations" {
  description = "Specific zones within the region to place GKE nodes. Subset the region zones to avoid GCE_STOCKOUT."
  type        = list(string)
}

variable "gke_private_cluster_enabled" {
  description = "Enable private nodes for GKE (nodes have no public IPs)"
  type        = bool
  default     = false
}

variable "gke_master_authorized_cidr" {
  description = "CIDR block authorized to access the GKE API server (equivalent of aks_authorized_ip_ranges)"
  type        = string
  default     = "0.0.0.0/0"
}

# ── Storage ───────────────────────────────────────────────────────────────────

variable "gcs_storage_class" {
  description = "Storage class for the GCS bucket (equivalent of Azure storage_replication_type)"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.gcs_storage_class)
    error_message = "Invalid GCS storage class."
  }
}

variable "gcs_location" {
  description = "Location for the GCS bucket — region, dual-region, or multi-region (e.g. US-EAST1, US, NAM4)"
  type        = string
  default     = "US-EAST1"
}
