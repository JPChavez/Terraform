# ── VPC ───────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# ── EKS ───────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL of the EKS API server"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "eks_kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.main.name}"
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA (Workload Identity equivalent)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "eks_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# ── ECR ───────────────────────────────────────────────────────────────────────

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.main.arn
}

# ── S3 ────────────────────────────────────────────────────────────────────────

output "s3_bucket_name" {
  description = "Name of the main S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the main S3 bucket"
  value       = aws_s3_bucket.main.arn
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

output "secrets_app_arn" {
  description = "ARN of the application Secrets Manager secret"
  value       = aws_secretsmanager_secret.app.arn
}

output "secrets_infra_arn" {
  description = "ARN of the infrastructure Secrets Manager secret"
  value       = aws_secretsmanager_secret.infra.arn
}

# ── KMS Keys ──────────────────────────────────────────────────────────────────

output "kms_eks_key_arn" {
  description = "ARN of the KMS key used for EKS secrets encryption"
  value       = aws_kms_key.eks.arn
}

output "kms_s3_key_arn" {
  description = "ARN of the KMS key used for S3 and ECR encryption"
  value       = aws_kms_key.s3.arn
}

output "kms_secrets_key_arn" {
  description = "ARN of the KMS key used for Secrets Manager encryption"
  value       = aws_kms_key.secrets.arn
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.main.private_ip
}

output "ec2_ssm_connect_command" {
  description = "AWS CLI command to connect to the instance via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.main.id} --region ${var.region}"
}

# ── AWS Glue ──────────────────────────────────────────────────────────────────

output "glue_database_name" {
  description = "Name of the Glue Data Catalog database"
  value       = aws_glue_catalog_database.main.name
}

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = aws_glue_job.main.name
}

# ── Amazon Kinesis ────────────────────────────────────────────────────────────

output "kinesis_stream_name" {
  description = "Name of the Kinesis data stream"
  value       = aws_kinesis_stream.main.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis data stream"
  value       = aws_kinesis_stream.main.arn
}

# ── Amazon Redshift Serverless ────────────────────────────────────────────────

output "redshift_namespace_name" {
  description = "Name of the Redshift Serverless namespace"
  value       = aws_redshiftserverless_namespace.main.namespace_name
}

output "redshift_workgroup_name" {
  description = "Name of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.workgroup_name
}

output "redshift_endpoint" {
  description = "Endpoint address of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.endpoint
}

# ── AWS Lambda ────────────────────────────────────────────────────────────────

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

# ── Amazon DynamoDB ───────────────────────────────────────────────────────────

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.main.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.main.arn
}

# ── AWS Step Functions ────────────────────────────────────────────────────────

output "sfn_state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.main.name
}

output "sfn_state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.main.arn
}

# ── Amazon SageMaker ──────────────────────────────────────────────────────────

output "sagemaker_domain_id" {
  description = "ID of the SageMaker domain"
  value       = aws_sagemaker_domain.main.id
}

output "sagemaker_domain_arn" {
  description = "ARN of the SageMaker domain"
  value       = aws_sagemaker_domain.main.arn
}

output "sagemaker_artifact_bucket" {
  description = "Name of the S3 bucket for SageMaker model artifacts"
  value       = aws_s3_bucket.sagemaker.bucket
}
