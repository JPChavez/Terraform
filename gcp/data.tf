data "google_project" "current" {}

# Bootstrap the GCS service agent so we can grant it KMS access before first bucket creation
data "google_storage_project_service_account" "gcs_account" {
  project = var.gcp_project_id
}
