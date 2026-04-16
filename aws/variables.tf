variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
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
  description = "Full project name used for tagging"
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
  description = "Owner of the resources — applied as a tag"
  type        = string
  default     = "Juan Pablo Chavez"
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ) — used for NAT gateways"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "eks_subnet_cidrs" {
  description = "CIDR blocks for private EKS subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "system_subnet_cidrs" {
  description = "CIDR blocks for private system subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "pe_subnet_cidrs" {
  description = "CIDR blocks for private VPC endpoint subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

# ── EKS ───────────────────────────────────────────────────────────────────────

variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "eks_system_instance_types" {
  description = "EC2 instance types for the EKS system node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_system_node_count" {
  description = "Desired number of nodes in the EKS system node group"
  type        = number
  default     = 1
}

variable "eks_user_instance_types" {
  description = "EC2 instance types for the EKS user node group"
  type        = list(string)
  default     = ["t3.xlarge"]
}

variable "eks_user_min_count" {
  description = "Minimum number of nodes in the EKS user node group"
  type        = number
  default     = 1
}

variable "eks_user_max_count" {
  description = "Maximum number of nodes in the EKS user node group"
  type        = number
  default     = 3
}

variable "eks_user_desired_count" {
  description = "Desired number of nodes in the EKS user node group"
  type        = number
  default     = 1
}

variable "eks_endpoint_public_access" {
  description = "Enable public access to the EKS API server endpoint"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS API server (when public access is enabled)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── ECR ───────────────────────────────────────────────────────────────────────

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain in ECR (lifecycle policy)"
  type        = number
  default     = 30
}

# ── Storage (S3) ──────────────────────────────────────────────────────────────

variable "s3_lifecycle_transition_days" {
  description = "Days after which S3 objects transition to STANDARD_IA storage class"
  type        = number
  default     = 90
}

variable "s3_lifecycle_expiration_days" {
  description = "Days after which non-current S3 object versions expire"
  type        = number
  default     = 365
}

# ── KMS ───────────────────────────────────────────────────────────────────────

variable "kms_deletion_window_days" {
  description = "Waiting period (in days) before KMS key deletion"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}
