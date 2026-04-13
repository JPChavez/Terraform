# Cloud Storage bucket — equivalent of Azure Storage Account
resource "google_storage_bucket" "main" {
  name          = local.gcs_bucket_name
  location      = var.gcs_location
  storage_class = var.gcs_storage_class
  force_destroy = false

  # Security best practices — equivalent of Azure Storage security settings
  uniform_bucket_level_access = true   # Enforces IAM over legacy ACLs (CKV_GCP_29)
  public_access_prevention    = "enforced" # Equivalent of allow_nested_items_to_be_public = false

  # Versioning — equivalent of blob versioning_enabled = true
  versioning {
    enabled = true
  }

  # Soft delete — equivalent of delete_retention_policy { days = 30 }
  soft_delete_policy {
    retention_duration_seconds = 2592000 # 30 days
  }

  # CMEK — equivalent of customer_managed_key block in Azure storage
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage.id
  }

  labels = local.common_labels

  depends_on = [google_kms_crypto_key_iam_member.storage_kms_encrypter]
}
