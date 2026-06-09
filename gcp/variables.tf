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

# ── Cloud Data Fusion ─────────────────────────────────────────────────────────

variable "data_fusion_edition" {
  description = "Cloud Data Fusion edition (DEVELOPER, BASIC, ENTERPRISE)"
  type        = string
  default     = "DEVELOPER"

  validation {
    condition     = contains(["DEVELOPER", "BASIC", "ENTERPRISE"], var.data_fusion_edition)
    error_message = "Data Fusion edition must be DEVELOPER, BASIC, or ENTERPRISE."
  }
}

# ── Cloud Pub/Sub ─────────────────────────────────────────────────────────────

variable "pubsub_message_retention_seconds" {
  description = "Message retention duration for the Pub/Sub topic in seconds (600–604800)"
  type        = number
  default     = 86400
}

# ── BigQuery ──────────────────────────────────────────────────────────────────

variable "bigquery_dataset_location" {
  description = "Location for the BigQuery dataset (region or multi-region, e.g. US, EU, us-central1)"
  type        = string
  default     = "US"
}

# ── Cloud Functions v2 ────────────────────────────────────────────────────────

variable "cloudfunctions_runtime" {
  description = "Runtime for Cloud Functions v2 (e.g. python311, nodejs20)"
  type        = string
  default     = "python311"
}

variable "cloudfunctions_max_instances" {
  description = "Maximum number of Cloud Functions v2 instances"
  type        = number
  default     = 10
}

# ── Firestore ─────────────────────────────────────────────────────────────────

variable "firestore_location_id" {
  description = "Location for the Firestore database (e.g. us-central, us-east1, nam5)"
  type        = string
  default     = "us-central"
}

# ── Cloud Filestore ───────────────────────────────────────────────────────────

variable "filestore_zone" {
  description = "Zone for the Filestore instance (BASIC tiers require a zone, e.g. us-east1-b)"
  type        = string
  default     = "us-east1-b"
}

variable "filestore_tier" {
  description = "Filestore service tier (BASIC_HDD, BASIC_SSD, ENTERPRISE)"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["BASIC_HDD", "BASIC_SSD", "HIGH_SCALE_SSD", "ENTERPRISE", "ZONAL", "REGIONAL"], var.filestore_tier)
    error_message = "Invalid Filestore tier."
  }
}

variable "filestore_capacity_gb" {
  description = "Capacity in GB for the Filestore share (BASIC_HDD min 1024, BASIC_SSD min 2560)"
  type        = number
  default     = 1024

  validation {
    condition     = var.filestore_capacity_gb >= 1024
    error_message = "Filestore capacity must be at least 1024 GB."
  }
}
