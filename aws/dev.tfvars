region          = "us-east-1"
environment     = "dev"
project         = "JProject"
project_acronym = "jp"
owner           = "Juan Pablo Chavez"

# Network
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.100.0/24", "10.0.101.0/24"]
eks_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
system_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
pe_subnet_cidrs     = ["10.0.5.0/24", "10.0.6.0/24"]

# EKS
eks_kubernetes_version     = "1.32"
eks_system_instance_types  = ["t3.medium"]
eks_system_node_count      = 1
eks_user_instance_types    = ["t3.xlarge"]
eks_user_min_count         = 1
eks_user_max_count         = 3
eks_user_desired_count     = 1
eks_endpoint_public_access = true
eks_public_access_cidrs    = ["189.217.80.179/32"]

# ECR
ecr_image_retention_count = 30

# S3
s3_lifecycle_transition_days = 90
s3_lifecycle_expiration_days = 365

# KMS
kms_deletion_window_days = 30

# Amazon Kinesis
kinesis_shard_count      = 1
kinesis_retention_period = 24

# Amazon Redshift Serverless
redshift_admin_username     = "rsadmin"
redshift_base_capacity_rpus = 8

# AWS Lambda
lambda_runtime     = "python3.11"
lambda_memory_size = 128
lambda_timeout     = 30

# Amazon DynamoDB
dynamodb_billing_mode = "PAY_PER_REQUEST"
dynamodb_hash_key     = "id"

# Amazon SageMaker
sagemaker_auth_mode = "IAM"
