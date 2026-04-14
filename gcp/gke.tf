# Dedicated GKE node Service Account — least privilege over the default Compute SA
# Equivalent of AKS SystemAssigned identity
resource "google_service_account" "gke_nodes" {
  account_id   = local.gke_node_sa_name
  display_name = "GKE Node Service Account — ${var.environment}"
}

# GKE cluster — regional for HA (equivalent of AKS Standard tier with zone redundancy)
resource "google_container_cluster" "main" {
  name     = local.gke_cluster_name
  location = var.region # Regional cluster spans 3 zones automatically

  # Remove default node pool — we manage pools explicitly below
  remove_default_node_pool = true
  initial_node_count       = 1

  # Constrain to specific zones to avoid GCE_STOCKOUT in the region.
  # Override with all region zones once capacity is restored.
  node_locations = var.gke_node_locations

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.gke.id

  # VPC-native (alias IP) mode — required for private clusters and network policy
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  min_master_version = var.gke_kubernetes_version

  # ── Security best practices ────────────────────────────────────────────────

  enable_shielded_nodes = true # Equivalent of enable_host_encryption in AKS

  # Workload Identity — allows GKE pods to use GCP service accounts without keys
  # Equivalent of AKS workload_identity_enabled + oidc_issuer_enabled
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
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

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Dataplane V2 — built-in network policy (equivalent of network_policy = "azure" in AKS)
  datapath_provider = "ADVANCED_DATAPATH"

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

# System node pool — dedicated to Kubernetes system components
# Equivalent of AKS default_node_pool with only_critical_addons_enabled = true
resource "google_container_node_pool" "system" {
  name     = "system"
  cluster  = google_container_cluster.main.id
  location = var.region

  node_count = var.gke_system_node_count

  node_config {
    machine_type = var.gke_system_machine_type
    disk_type    = "pd-ssd"
    disk_size_gb = 100

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Shielded nodes — equivalent of enable_host_encryption in AKS
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Block legacy metadata endpoint; enforce Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Taint system nodes — only kube-system pods scheduled here
    # Equivalent of only_critical_addons_enabled = true
    taint {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = local.common_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# User node pool — for application workloads with autoscaling
# Equivalent of azurerm_kubernetes_cluster_node_pool.user
resource "google_container_node_pool" "user" {
  name     = "user"
  cluster  = google_container_cluster.main.id
  location = var.region

  # Cluster autoscaler — equivalent of enable_auto_scaling in AKS
  autoscaling {
    min_node_count = var.gke_user_min_count
    max_node_count = var.gke_user_max_count
  }

  node_config {
    machine_type = var.gke_user_machine_type
    disk_type    = "pd-ssd"
    disk_size_gb = 100

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = local.common_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}
