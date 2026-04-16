# ── VPC Endpoints — equivalent of Azure Private Endpoints ─────────────────────
# Interface endpoints keep traffic for ECR, Secrets Manager, CloudWatch, and STS
# entirely within the VPC. S3 uses a free Gateway endpoint.

locals {
  vpc_endpoint_subnet_ids = aws_subnet.endpoints[*].id
  vpc_endpoint_sg_ids     = [aws_security_group.vpc_endpoints.id]
}

# ── S3 Gateway Endpoint (free, no SG required) ────────────────────────────────

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.eks[*].id,
    [aws_route_table.system.id],
  )

  tags = { Name = "vpce-s3-${local.prefix}" }
}

# ── ECR API — pulls image manifests ───────────────────────────────────────────

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_endpoint_subnet_ids
  security_group_ids  = local.vpc_endpoint_sg_ids
  private_dns_enabled = true

  tags = { Name = "vpce-ecr-api-${local.prefix}" }
}

# ── ECR DKR — pulls image layers ──────────────────────────────────────────────

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_endpoint_subnet_ids
  security_group_ids  = local.vpc_endpoint_sg_ids
  private_dns_enabled = true

  tags = { Name = "vpce-ecr-dkr-${local.prefix}" }
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_endpoint_subnet_ids
  security_group_ids  = local.vpc_endpoint_sg_ids
  private_dns_enabled = true

  tags = { Name = "vpce-secretsmanager-${local.prefix}" }
}

# ── CloudWatch Logs ───────────────────────────────────────────────────────────

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_endpoint_subnet_ids
  security_group_ids  = local.vpc_endpoint_sg_ids
  private_dns_enabled = true

  tags = { Name = "vpce-logs-${local.prefix}" }
}

# ── STS — required for IRSA token exchange ────────────────────────────────────

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_endpoint_subnet_ids
  security_group_ids  = local.vpc_endpoint_sg_ids
  private_dns_enabled = true

  tags = { Name = "vpce-sts-${local.prefix}" }
}

# ── EC2 — required for EKS node bootstrap and autoscaling ─────────────────────

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpc_endpoint_subnet_ids
  security_group_ids  = local.vpc_endpoint_sg_ids
  private_dns_enabled = true

  tags = { Name = "vpce-ec2-${local.prefix}" }
}
