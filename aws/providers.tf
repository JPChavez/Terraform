provider "aws" {
  region = var.region

  # All resources inherit these tags automatically via default_tags
  default_tags {
    tags = local.common_tags
  }
}

# TLS provider — used to retrieve the OIDC thumbprint for the EKS IRSA OIDC provider
provider "tls" {}
