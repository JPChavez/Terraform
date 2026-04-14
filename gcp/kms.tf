# Cloud KMS Key Ring — groups all environment keys (equivalent of Azure Key Vault)
# Note: Key rings cannot be deleted once created — plan accordingly
resource "google_kms_key_ring" "main" {
  name     = local.kms_keyring_name
  location = var.region
}

# Key for GKE etcd + node disk encryption
# Equivalent of: azurerm_key_vault_key.disk_encryption + azurerm_disk_encryption_set
resource "google_kms_crypto_key" "gke" {
  name     = local.kms_key_gke_name
  key_ring = google_kms_key_ring.main.id

  rotation_period = "7776000s" # 90-day auto-rotation (equivalent of auto_key_rotation_enabled)

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM" # Hardware-backed — equivalent of RSA-HSM in Key Vault
  }

  labels = local.common_labels
}

# Key for GCS bucket CMEK
# Equivalent of: azurerm_key_vault_key.storage
resource "google_kms_crypto_key" "storage" {
  name     = local.kms_key_storage_name
  key_ring = google_kms_key_ring.main.id

  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM"
  }

  labels = local.common_labels
}

# Key for Artifact Registry CMEK
# No direct Azure equivalent — GCP requires explicit CMEK for Artifact Registry
resource "google_kms_crypto_key" "artifact_registry" {
  name     = local.kms_key_ar_name
  key_ring = google_kms_key_ring.main.id

  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM"
  }

  labels = local.common_labels
}
