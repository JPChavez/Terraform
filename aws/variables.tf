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

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "ec2_instance_type" {
  description = "EC2 instance type for the VM"
  type        = string
  default     = "t3.medium"
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "kms_deletion_window_days" {
  description = "Waiting period (in days) before KMS key deletion"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

# ── Amazon Kinesis ────────────────────────────────────────────────────────────

variable "kinesis_shard_count" {
  description = "Number of shards for the Kinesis data stream"
  type        = number
  default     = 1
}

variable "kinesis_retention_period" {
  description = "Data retention period for the Kinesis data stream in hours (24–8760)"
  type        = number
  default     = 24
}

# ── Amazon Redshift Serverless ────────────────────────────────────────────────

variable "redshift_admin_username" {
  description = "Admin username for the Redshift Serverless namespace"
  type        = string
  default     = "rsadmin"
}

variable "redshift_base_capacity_rpus" {
  description = "Base capacity in Redshift Processing Units (RPUs) for the workgroup (8–512)"
  type        = number
  default     = 8
}

# ── AWS Lambda ────────────────────────────────────────────────────────────────

variable "lambda_runtime" {
  description = "Runtime for the Lambda function (e.g. python3.11, nodejs20.x)"
  type        = string
  default     = "python3.11"
}

variable "lambda_memory_size" {
  description = "Memory allocated to the Lambda function in MB"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 30
}

# ── Amazon DynamoDB ───────────────────────────────────────────────────────────

variable "dynamodb_billing_mode" {
  description = "Billing mode for the DynamoDB table (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_hash_key" {
  description = "Hash key (partition key) attribute name for the DynamoDB table"
  type        = string
  default     = "id"
}

# ── Amazon SageMaker ──────────────────────────────────────────────────────────

variable "sagemaker_auth_mode" {
  description = "Authentication mode for the SageMaker domain (IAM or SSO)"
  type        = string
  default     = "IAM"

  validation {
    condition     = contains(["IAM", "SSO"], var.sagemaker_auth_mode)
    error_message = "SageMaker auth mode must be IAM or SSO."
  }
}
