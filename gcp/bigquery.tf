# ── BigQuery — equivalent of Azure Synapse Analytics ─────────────────────────

resource "google_bigquery_dataset" "main" {
  dataset_id                 = local.bigquery_dataset_id
  location                   = var.bigquery_dataset_location
  project                    = var.gcp_project_id
  friendly_name              = "JProject ${var.environment}"
  description                = "Main analytics dataset for ${var.project} (${var.environment})"
  delete_contents_on_destroy = var.environment != "prod"

  # Default table expiration — null means tables never expire automatically
  default_table_expiration_ms = null

  # Encrypt dataset tables with the existing Cloud KMS storage key (CMEK)
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.storage.id
  }

  # Project members inherit access via IAM; define fine-grained access here
  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  labels = local.common_labels
}

# Grant the GKE node SA read access to query BigQuery tables
resource "google_bigquery_dataset_iam_member" "gke_bq_viewer" {
  dataset_id = google_bigquery_dataset.main.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
  project    = var.gcp_project_id
}
