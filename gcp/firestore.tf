# ── Firestore — equivalent of Azure Cosmos DB ─────────────────────────────────
# Firestore Native mode is the document-DB equivalent of Cosmos DB Core (SQL) API.
# For strongly-consistent global distribution, consider Cloud Spanner instead.

resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  project            = var.gcp_project_id
  disable_on_destroy = false
}

resource "google_firestore_database" "main" {
  project     = var.gcp_project_id
  name        = local.firestore_database_id
  location_id = var.firestore_location_id
  type        = "FIRESTORE_NATIVE"

  # Protect from accidental deletion in production; disable for easy cleanup in dev/uat
  delete_protection_state = var.environment == "prod" ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"

  # "DELETE" drops the database on terraform destroy; change to "ABANDON" to retain data
  deletion_policy = "DELETE"

  depends_on = [google_project_service.firestore]
}

# Grant the GKE node SA access to read/write Firestore documents
resource "google_project_iam_member" "gke_firestore_user" {
  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
