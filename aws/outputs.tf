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
