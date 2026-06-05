# Cloud Filestore — managed NFS for shared file storage (ReadWriteMany for GKE workloads)
resource "google_filestore_instance" "main" {
  name     = local.filestore_name
  location = var.filestore_zone
  tier     = var.filestore_tier

  file_shares {
    name        = "data"
    capacity_gb = var.filestore_capacity_gb
  }

  networks {
    network      = google_compute_network.main.name
    modes        = ["MODE_IPV4"]
    connect_mode = "DIRECT_PEERING"
  }

  labels = local.common_labels
}
