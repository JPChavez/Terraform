# ── Cloud Functions v2 — equivalent of Azure Function App ────────────────────

# Minimal placeholder source — replace with real application code via CI/CD
data "archive_file" "cf_source" {
  type        = "zip"
  output_path = "${path.module}/.build/function.zip"

  source {
    content  = "def handler(request):\n    return 'OK', 200\n"
    filename = "main.py"
  }

  source {
    content  = ""
    filename = "requirements.txt"
  }
}

# GCS bucket to store Cloud Functions source ZIPs
resource "google_storage_bucket" "cf_source" {
  name     = local.cf_source_bucket_name
  location = var.gcs_location
  project  = var.gcp_project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  labels = local.common_labels
}

resource "google_storage_bucket_object" "cf_source" {
  name   = "source-${data.archive_file.cf_source.output_md5}.zip"
  bucket = google_storage_bucket.cf_source.name
  source = data.archive_file.cf_source.output_path
}

# Dedicated service account for the function runtime
resource "google_service_account" "cf_function" {
  account_id   = local.cf_sa_name
  display_name = "Cloud Functions SA — ${local.prefix}"
  project      = var.gcp_project_id
}

resource "google_cloudfunctions2_function" "main" {
  name     = local.cf_function_name
  location = var.region
  project  = var.gcp_project_id

  build_config {
    runtime     = var.cloudfunctions_runtime
    entry_point = "handler"

    source {
      storage_source {
        bucket = google_storage_bucket.cf_source.name
        object = google_storage_bucket_object.cf_source.name
      }
    }
  }

  service_config {
    min_instance_count    = 0
    max_instance_count    = var.cloudfunctions_max_instances
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cf_function.email

    environment_variables = {
      ENVIRONMENT = var.environment
    }
  }

  labels = local.common_labels
}

# Allow the function SA to read from the main GCS bucket
resource "google_storage_bucket_iam_member" "cf_storage_reader" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cf_function.email}"
}
