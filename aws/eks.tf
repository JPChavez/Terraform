# ── CloudWatch Log Group for EKS ─────────────────────────────────────────────
# Must exist before the cluster; EKS publishes control plane logs here.

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.eks_cluster_name}/cluster"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_kubernetes_version

  # CKV_AWS_37: enable all control plane log types
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # CKV_AWS_58: encrypt Kubernetes secrets with KMS CMK
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  vpc_config {
    subnet_ids              = concat(aws_subnet.eks[*].id, aws_subnet.system[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true  # CKV_AWS_39
    endpoint_public_access  = var.eks_endpoint_public_access
    public_access_cidrs     = var.eks_endpoint_public_access ? var.eks_public_access_cidrs : null
  }

  # Use the newer access entries API for cluster authentication management
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks,
  ]

  tags = { Name = local.eks_cluster_name }
}

# ── System Node Group — equivalent of AKS default/system node pool ───────────

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.prefix}-system"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks[*].id
  instance_types  = var.eks_system_instance_types

  # CKV_AWS_341: encrypt root EBS volume with KMS
  launch_template {
    id      = aws_launch_template.system_nodes.id
    version = aws_launch_template.system_nodes.latest_version
  }

  scaling_config {
    desired_size = var.eks_system_node_count
    min_size     = var.eks_system_node_count
    max_size     = var.eks_system_node_count
  }

  update_config {
    max_unavailable_percentage = 33
  }

  # Taint system nodes so only critical workloads are scheduled here
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
    aws_iam_role_policy_attachment.eks_ebs_csi_policy,
  ]

  tags = { Name = "${local.prefix}-system" }
}

# ── User Node Group — equivalent of AKS user node pool with autoscaling ───────

resource "aws_eks_node_group" "user" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.prefix}-user"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks[*].id
  instance_types  = var.eks_user_instance_types

  # CKV_AWS_341: encrypt root EBS volume with KMS
  launch_template {
    id      = aws_launch_template.user_nodes.id
    version = aws_launch_template.user_nodes.latest_version
  }

  scaling_config {
    desired_size = var.eks_user_desired_count
    min_size     = var.eks_user_min_count
    max_size     = var.eks_user_max_count
  }

  update_config {
    max_unavailable_percentage = 33
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
    aws_iam_role_policy_attachment.eks_ebs_csi_policy,
  ]

  tags = { Name = "${local.prefix}-user" }
}

# ── Launch Templates — enforce EBS encryption on nodes ────────────────────────

resource "aws_launch_template" "system_nodes" {
  name_prefix = "${local.prefix}-system-lt-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true  # CKV_AWS_341
      kms_key_id            = aws_kms_key.eks.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only — CKV_AWS_79
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.prefix}-system-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.prefix}-system-node-vol" })
  }
}

resource "aws_launch_template" "user_nodes" {
  name_prefix = "${local.prefix}-user-lt-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      encrypted             = true  # CKV_AWS_341
      kms_key_id            = aws_kms_key.eks.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only — CKV_AWS_79
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.prefix}-user-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.prefix}-user-node-vol" })
  }
}

# ── EKS Add-ons ───────────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.system]
}
