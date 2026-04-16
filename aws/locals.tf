locals {
  # Naming convention mirrors Azure/GCP: <project_acronym>-<resource>-<environment>
  prefix = "${var.project_acronym}-${var.environment}"

  # EKS — equivalent of AKS
  eks_cluster_name = "${var.project_acronym}-eks-${var.environment}"

  # ECR — equivalent of ACR (lowercase, hyphens allowed in AWS)
  ecr_name = lower("${var.project_acronym}-ecr-${var.environment}")

  # S3 — globally unique; account ID used as suffix like project_id in GCP
  s3_bucket_name      = lower("${var.project_acronym}-s3-${var.environment}-${data.aws_caller_identity.current.account_id}")
  s3_logs_bucket_name = lower("${var.project_acronym}-s3-logs-${var.environment}-${data.aws_caller_identity.current.account_id}")

  # Secrets Manager — equivalent of Key Vault
  secrets_prefix = "${var.project_acronym}-sm-${var.environment}"

  # Network
  vpc_name           = "${var.project_acronym}-vpc-${var.environment}"
  subnet_eks_name    = "${var.project_acronym}-snet-eks-${var.environment}"
  subnet_system_name = "${var.project_acronym}-snet-system-${var.environment}"
  subnet_pe_name     = "${var.project_acronym}-snet-pe-${var.environment}"
  subnet_pub_name    = "${var.project_acronym}-snet-pub-${var.environment}"

  # KMS key aliases — equivalent of Key Vault key names
  kms_alias_eks     = "alias/${var.project_acronym}-key-eks-${var.environment}"
  kms_alias_s3      = "alias/${var.project_acronym}-key-s3-${var.environment}"
  kms_alias_secrets = "alias/${var.project_acronym}-key-sm-${var.environment}"

  # common_tags are applied to all resources via provider default_tags and explicit tags blocks.
  # Note: AWS tag values are strings; owner spaces are preserved (unlike GCP labels).
  common_tags = {
    project     = var.project
    environment = var.environment
    region      = var.region
    owner       = var.owner
    managed_by  = "terraform"
  }
}
