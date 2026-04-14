# VPC — global network, regional subnets (equivalent of Azure VNet)
resource "google_compute_network" "main" {
  name                    = local.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# GKE subnet — primary range for nodes, secondary ranges for pods + services
resource "google_compute_subnetwork" "gke" {
  name          = local.subnet_gke
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.vpc_cidr

  private_ip_google_access = true # Allow nodes to reach Google APIs without external IPs

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# System subnet — for tooling and operators (equivalent of Azure system subnet)
resource "google_compute_subnetwork" "system" {
  name          = local.subnet_system
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.system_subnet_cidr

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router — required for Cloud NAT
resource "google_compute_router" "main" {
  name    = "${local.prefix}-router"
  region  = var.region
  network = google_compute_network.main.id
}

# Cloud NAT — allows private nodes to pull images + updates without public IPs
# Equivalent of the outbound_type = "loadBalancer" in AKS
resource "google_compute_router_nat" "main" {
  name                               = "${local.prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── Firewall rules — equivalent of Azure NSG ──────────────────────────────────

# Deny all ingress by default (lowest priority — any allow rule overrides this)
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${local.prefix}-deny-all-ingress"
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 65534
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}

# Allow all traffic within the VPC (node-to-node, pod-to-pod)
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.prefix}-allow-internal"
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000
  allow {
    protocol = "all"
  }
  source_ranges = [
    var.vpc_cidr,
    var.pods_cidr,
    var.system_subnet_cidr,
  ]
}

# Allow GCP health check probes (required for load balancers)
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${local.prefix}-allow-health-checks"
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000
  allow {
    protocol = "tcp"
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}
