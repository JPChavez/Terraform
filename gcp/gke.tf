# GKE Autopilot cluster — GCP manages nodes, scaling, and infrastructure
# Equivalent of AKS with system-assigned identity; billing per pod, not per node
resource "google_container_cluster" "main" {
  #checkov:skip=CKV_GCP_18:Public endpoint intentional for dev; access restricted to operator IP via master_authorized_networks_config
  #checkov:skip=CKV_GCP_65:Google Groups RBAC requires Google Workspace / Cloud Identity, not provisioned for this project
  name     = local.gke_cluster_name
  location = var.region # Regional cluster spans 3 zones automatically

  # Autopilot — GCP manages nodes, node pools, and infrastructure
  enable_autopilot = true

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.gke.id

  # VPC-native (alias IP) mode — required for Autopilot
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # ── Security best practices ────────────────────────────────────────────────

  # Workload Identity — allows GKE pods to use GCP service accounts without keys
  # Equivalent of AKS workload_identity_enabled + oidc_issuer_enabled
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  # Disable client certificate auth — passwords/certs replaced by RBAC + Workload Identity (CKV_GCP_13)
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Binary Authorization — only deploy signed/verified container images
  # Equivalent of ACR trust_policy
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Private cluster config — enable_private_nodes driven by var (parallel to aks_private_cluster_enabled)
  # master_ipv4_cidr_block is only valid when enable_private_nodes = true; omit it otherwise
  # to avoid forcing cluster replacement on non-private clusters.
  private_cluster_config {
    enable_private_nodes    = var.gke_private_cluster_enabled
    enable_private_endpoint = false # Keep master publicly reachable for operator access
    master_ipv4_cidr_block  = var.gke_private_cluster_enabled ? var.master_cidr : null
  }

  # Restrict API server access — equivalent of aks_authorized_ip_ranges
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.gke_master_authorized_cidr
      display_name = "operator-access"
    }
  }

  # etcd encryption at rest with CMEK — equivalent of AKS disk_encryption_set_id
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke.id
  }

  # Cloud Logging + Cloud Monitoring — equivalent of AKS oms_agent + microsoft_defender
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Daily 4h window — satisfies GKE's requirement of ≥48h availability per 32-day period
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  release_channel {
    channel = "REGULAR" # Auto-upgrades within the regular release cadence
  }

  deletion_protection = false # Set true in production after initial deployment

  resource_labels = local.common_labels

  depends_on = [google_kms_crypto_key_iam_member.gke_kms_encrypter]
}
