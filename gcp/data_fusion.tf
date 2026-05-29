# ── Cloud Data Fusion — equivalent of Azure Data Factory ─────────────────────

resource "google_project_service" "data_fusion" {
  service            = "datafusion.googleapis.com"
  project            = var.gcp_project_id
  disable_on_destroy = false
}

resource "google_data_fusion_instance" "main" {
  name    = local.data_fusion_name
  region  = var.region
  project = var.gcp_project_id

  # DEVELOPER is the lowest-cost edition and sufficient for dev/uat.
  # Upgrade to BASIC or ENTERPRISE for private VPC connectivity in production.
  type = var.data_fusion_edition

  labels = local.common_labels

  depends_on = [google_project_service.data_fusion]
}
