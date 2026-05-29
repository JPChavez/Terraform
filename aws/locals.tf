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
  kms_alias_ec2     = "alias/${var.project_acronym}-key-ec2-${var.environment}"

  # EC2
  ec2_name = "${var.project_acronym}-ec2-${var.environment}"

  # AWS Glue — equivalent of Azure Data Factory
  glue_database_name   = "${var.project_acronym}-glue-db-${var.environment}"
  glue_job_name        = "${var.project_acronym}-glue-job-${var.environment}"
  glue_role_name       = "${var.project_acronym}-role-glue-${var.environment}"
  glue_sec_config_name = "${var.project_acronym}-glue-sec-${var.environment}"
  kms_alias_glue       = "alias/${var.project_acronym}-key-glue-${var.environment}"

  # Amazon Kinesis — equivalent of Azure Event Hub
  kinesis_stream_name = "${var.project_acronym}-kin-${var.environment}"
  kms_alias_kinesis   = "alias/${var.project_acronym}-key-kin-${var.environment}"

  # Amazon Redshift Serverless — equivalent of Azure Synapse Analytics
  redshift_namespace_name = "${var.project_acronym}-rsns-${var.environment}"
  redshift_workgroup_name = "${var.project_acronym}-rswg-${var.environment}"
  redshift_role_name      = "${var.project_acronym}-role-rs-${var.environment}"
  kms_alias_redshift      = "alias/${var.project_acronym}-key-rs-${var.environment}"

  # AWS Lambda — equivalent of Azure Function App
  lambda_function_name = "${var.project_acronym}-lambda-${var.environment}"
  lambda_role_name     = "${var.project_acronym}-role-lambda-${var.environment}"
  kms_alias_lambda     = "alias/${var.project_acronym}-key-lambda-${var.environment}"

  # Amazon DynamoDB — equivalent of Azure Cosmos DB
  dynamodb_table_name = "${var.project_acronym}-ddb-${var.environment}"
  kms_alias_dynamodb  = "alias/${var.project_acronym}-key-ddb-${var.environment}"

  # AWS Step Functions — equivalent of Azure Logic Apps
  sfn_state_machine_name = "${var.project_acronym}-sfn-${var.environment}"
  sfn_role_name          = "${var.project_acronym}-role-sfn-${var.environment}"

  # Amazon SageMaker — equivalent of Azure AI Foundry
  sagemaker_domain_name = "${var.project_acronym}-smd-${var.environment}"
  sagemaker_role_name   = "${var.project_acronym}-role-sm-${var.environment}"
  sagemaker_bucket_name = lower("${var.project_acronym}-smd-art-${var.environment}-${data.aws_caller_identity.current.account_id}")
  kms_alias_sagemaker   = "alias/${var.project_acronym}-key-smml-${var.environment}"

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
