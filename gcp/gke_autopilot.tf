# GKE Autopilot cluster — Google manages nodes, scaling, and upgrades automatically
# Equivalent of AKS with node auto-provisioning; no node pools to define
resource "google_container_cluster" "autopilot" {
  #checkov:skip=CKV_GCP_18:Public endpoint intentional for dev; access restricted to operator IP via master_authorized_networks_config
  #checkov:skip=CKV_GCP_65:Google Groups RBAC requires Google Workspace / Cloud Identity, not provisioned for this project
  name     = local.gke_autopilot_name
  location = var.region

  enable_autopilot = true

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.gke_autopilot.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "autopilot-pods"
    services_secondary_range_name = "autopilot-services"
  }

  # Workload Identity — allows pods to use GCP service accounts without key files
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Binary Authorization — only deploy signed/verified container images
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  private_cluster_config {
    enable_private_nodes    = var.gke_autopilot_private_cluster_enabled
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_autopilot_private_cluster_enabled ? var.gke_autopilot_master_cidr : null
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.gke_autopilot_master_authorized_cidr
      display_name = "operator-access"
    }
  }

  # etcd encryption at rest with CMEK — reuses the project-level GKE key
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke.id
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  deletion_protection = false

  resource_labels = local.common_labels

  depends_on = [google_kms_crypto_key_iam_member.gke_kms_encrypter]
}
