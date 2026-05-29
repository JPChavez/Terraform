# ── Vertex AI — equivalent of Azure AI Foundry ────────────────────────────────
# Vertex AI is the GCP managed ML platform backing AI Foundry-equivalent workflows:
# model training, Pipelines, Feature Store, Model Registry, and online endpoints.
# Enable the API and provision the service account and artifact bucket here;
# Vertex AI Workbench instances and pipelines are deployed separately.

resource "google_project_service" "vertex_ai" {
  service            = "aiplatform.googleapis.com"
  project            = var.gcp_project_id
  disable_on_destroy = false
}

# Dedicated service account for Vertex AI workloads
resource "google_service_account" "vertex_ai" {
  account_id   = local.vertex_ai_sa_name
  display_name = "Vertex AI SA — ${local.prefix}"
  project      = var.gcp_project_id
}

# Dedicated GCS bucket for Vertex AI model artifacts, pipeline outputs, and datasets
resource "google_storage_bucket" "vertex_ai" {
  name     = local.vertex_ai_bucket_name
  location = var.gcs_location
  project  = var.gcp_project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Encrypt with the existing Cloud KMS storage key (CMEK)
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage.id
  }

  versioning {
    enabled = true
  }

  labels = local.common_labels
}

# Grant KMS encrypt/decrypt on the storage key to the Vertex AI SA
resource "google_kms_crypto_key_iam_member" "vertex_ai_kms_encrypter" {
  crypto_key_id = google_kms_crypto_key.storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vertex_ai.email}"
}

# ── IAM roles for the Vertex AI service account ───────────────────────────────

resource "google_project_iam_member" "vertex_ai_user" {
  project = var.gcp_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.vertex_ai.email}"
}

resource "google_storage_bucket_iam_member" "vertex_ai_artifact_storage" {
  bucket = google_storage_bucket.vertex_ai.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.vertex_ai.email}"
}

resource "google_artifact_registry_repository_iam_member" "vertex_ai_ar_reader" {
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vertex_ai.email}"
}
