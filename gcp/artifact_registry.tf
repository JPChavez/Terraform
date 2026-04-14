# Artifact Registry — equivalent of Azure Container Registry (ACR)
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = local.ar_repository_id
  description   = "Docker container registry for ${var.project} ${var.environment}"
  format        = "DOCKER"

  # CMEK — equivalent of ACR CMK (no explicit CMK in azurerm ACR but present in premium)
  kms_key_name = google_kms_crypto_key.artifact_registry.id

  docker_config {
    immutable_tags = false # Allow tag overwrites (set true in prod for strict governance)
  }

  # Cleanup policy — remove untagged images after 7 days
  # Equivalent of ACR retention_policy { days = 7; enabled = true }
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }

  labels = local.common_labels

  depends_on = [google_kms_crypto_key_iam_member.ar_kms_encrypter]
}
