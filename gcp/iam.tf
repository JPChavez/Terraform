# ── KMS — GKE etcd encryption ─────────────────────────────────────────────────
# Grant the GKE container engine robot SA permission to use the KMS key for etcd encryption
# Equivalent of azurerm_role_assignment.des_kv_crypto (DES → Key Vault Crypto User)
resource "google_kms_crypto_key_iam_member" "gke_kms_encrypter" {
  crypto_key_id = google_kms_crypto_key.gke.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

# ── KMS — GCS CMEK ────────────────────────────────────────────────────────────
# Grant the GCS service agent permission to encrypt/decrypt bucket data
# Equivalent of azurerm_role_assignment.storage_identity_kv_crypto
resource "google_kms_crypto_key_iam_member" "storage_kms_encrypter" {
  crypto_key_id = google_kms_crypto_key.storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# ── KMS — Artifact Registry CMEK ─────────────────────────────────────────────
# Bootstrap the AR service agent via gcloud before granting KMS access.
# google_project_service_identity (beta) has a propagation delay that causes
# the IAM binding to race; local-exec ensures the agent exists synchronously.
resource "null_resource" "ar_service_agent_bootstrap" {
  triggers = {
    project = var.gcp_project_id
  }

  provisioner "local-exec" {
    command = "gcloud beta services identity create --service=artifactregistry.googleapis.com --project=${var.gcp_project_id}"
  }
}

resource "google_kms_crypto_key_iam_member" "ar_kms_encrypter" {
  crypto_key_id = google_kms_crypto_key.artifact_registry.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"

  depends_on = [null_resource.ar_service_agent_bootstrap]
}

# ── GKE Node SA — Artifact Registry pull access ───────────────────────────────
# Equivalent of azurerm_role_assignment.aks_acr_pull (AcrPull)
resource "google_artifact_registry_repository_iam_member" "gke_ar_reader" {
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── GKE Node SA — GCS access ──────────────────────────────────────────────────
# Equivalent of azurerm_role_assignment.storage_aks_contributor (Storage Blob Data Contributor)
resource "google_storage_bucket_iam_member" "gke_storage_object_user" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── GKE Node SA — Cloud Logging ───────────────────────────────────────────────
# Allows nodes to write logs to Cloud Logging (equivalent of AKS oms_agent)
resource "google_project_iam_member" "gke_node_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── GKE Node SA — Cloud Monitoring ───────────────────────────────────────────
resource "google_project_iam_member" "gke_node_monitoring_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── GKE Node SA — GKE metadata access (required for Workload Identity) ────────
resource "google_project_iam_member" "gke_node_metadata_viewer" {
  project = var.gcp_project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
