# ── VPC ───────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required for VPC endpoint DNS resolution
  enable_dns_support   = true # Required for private hosted zones

  tags = { Name = local.vpc_name }
}

# ── VPC Flow Logs — CKV2_AWS_11 ───────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${local.prefix}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

# ── Default Security Group — CKV2_AWS_12 ──────────────────────────────────────
# Ensure the default SG has no inbound/outbound rules (deny all by default)

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # No ingress or egress rules — all traffic denied
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${local.prefix}" }
}

# ── Public Subnets (for NAT gateways) ─────────────────────────────────────────

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Instances in public subnets must NOT auto-assign public IPs
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${local.subnet_pub_name}-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "rt-public-${local.prefix}" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── NAT Gateway (single, in AZ-1) ─────────────────────────────────────────────
# One NAT gateway is sufficient for dev/uat. For prod, add a second EIP + NAT
# in the second AZ and update the private route tables to use per-AZ NAT gateways.

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "eip-nat-${local.prefix}" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "ngw-${local.prefix}" }
}

# ── Private EKS Subnets ────────────────────────────────────────────────────────
# Tagged for internal ELBs and EKS cluster discovery

resource "aws_subnet" "eks" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.eks_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                                = "${local.subnet_eks_name}-${count.index + 1}"
    "kubernetes.io/role/internal-elb"                   = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}"   = "owned"
  }
}

resource "aws_route_table" "eks" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "rt-eks-${count.index + 1}-${local.prefix}" }
}

resource "aws_route_table_association" "eks" {
  count          = 2
  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.eks[count.index].id
}

# ── Private System Subnets ────────────────────────────────────────────────────

resource "aws_subnet" "system" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.system_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${local.subnet_system_name}-${count.index + 1}" }
}

resource "aws_route_table" "system" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "rt-system-${local.prefix}" }
}

resource "aws_route_table_association" "system" {
  count          = 2
  subnet_id      = aws_subnet.system[count.index].id
  route_table_id = aws_route_table.system.id
}

# ── Private VPC Endpoint Subnets ──────────────────────────────────────────────
# Dedicated subnets for VPC interface endpoints — equivalent of Azure PE subnet

resource "aws_subnet" "endpoints" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.pe_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${local.subnet_pe_name}-${count.index + 1}" }
}

# ── Security Groups ───────────────────────────────────────────────────────────

# EKS control plane security group
resource "aws_security_group" "eks_cluster" {
  name        = "sg-eks-cluster-${local.prefix}"
  description = "Security group for the EKS control plane"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "sg-eks-cluster-${local.prefix}" }
}

resource "aws_security_group_rule" "eks_cluster_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
  description       = "Allow all outbound traffic from control plane"
}

# EKS worker node security group
resource "aws_security_group" "eks_nodes" {
  name        = "sg-eks-nodes-${local.prefix}"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "sg-eks-nodes-${local.prefix}" }
}

resource "aws_security_group_rule" "nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow all outbound traffic from nodes"
}

resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_nodes.id
  description              = "Allow node-to-node communication"
}

resource "aws_security_group_rule" "nodes_from_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
  description              = "Allow traffic from control plane to nodes"
}

# VPC endpoint security group — HTTPS from within the VPC only
resource "aws_security_group" "vpc_endpoints" {
  name        = "sg-vpc-endpoints-${local.prefix}"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC CIDR"
  }

  tags = { Name = "sg-vpc-endpoints-${local.prefix}" }
}
