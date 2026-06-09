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
    command = "gcloud --quiet beta services identity create --service=artifactregistry.googleapis.com --project=${var.gcp_project_id}"
  }
}

resource "google_kms_crypto_key_iam_member" "ar_kms_encrypter" {
  crypto_key_id = google_kms_crypto_key.artifact_registry.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"

  depends_on = [null_resource.ar_service_agent_bootstrap]
}
