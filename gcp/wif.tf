# Workload Identity Federation — Azure DevOps pipeline → GCP
#
# Allows gcp-pipelines.yml to authenticate as the pipeline service account
# using an ADO OIDC token, replacing the GCP_CREDENTIALS_JSON secret key.
#
# ADO Org: jpablerasazure  |  ADO Org ID: 565fad02-6dbb-4a59-9f09-c3d6edfc666e

# ── Pipeline service account ──────────────────────────────────────────────────
# Equivalent of the Azure DevOps service connection identity in Azure
resource "google_service_account" "pipeline" {
  account_id   = "${var.project_acronym}-sa-pipeline-${var.environment}"
  display_name = "ADO Pipeline Service Account — ${var.environment}"
  project      = var.gcp_project_id
}

# ── Pipeline SA roles — Terraform needs full control over all managed resources ─
resource "google_project_iam_member" "pipeline_container_admin" {
  project = var.gcp_project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_iam_sa_admin" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_kms_admin" {
  project = var.gcp_project_id
  role    = "roles/cloudkms.admin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_ar_admin" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_network_admin" {
  project = var.gcp_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_project_iam_admin" {
  project = var.gcp_project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

# ── WIF pool ──────────────────────────────────────────────────────────────────
resource "google_iam_workload_identity_pool" "ado" {
  workload_identity_pool_id = "${var.project_acronym}-wif-pool-${var.environment}"
  display_name              = "ADO Pipeline Pool — ${var.environment}"
  description               = "Workload Identity pool for Azure DevOps pipelines"
  project                   = var.gcp_project_id
}

# ── WIF OIDC provider — points to the ADO org's token issuer ──────────────────
resource "google_iam_workload_identity_pool_provider" "ado" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.ado.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.project_acronym}-wif-provider-${var.environment}"
  display_name                       = "ADO OIDC Provider — ${var.environment}"
  project                            = var.gcp_project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.aud"        = "assertion.aud"
  }

  # Only allow tokens issued for this specific ADO org
  attribute_condition = "attribute.aud==\"api://AzureADTokenExchange\""

  oidc {
    # Issuer URL uses the ADO organization ID (not the name)
    # jpablerasazure → 565fad02-6dbb-4a59-9f09-c3d6edfc666e
    issuer_uri = "https://vstoken.dev.azure.com/565fad02-6dbb-4a59-9f09-c3d6edfc666e"
  }
}

# ── Bind — allow ADO pipeline tokens to impersonate the pipeline SA ───────────
resource "google_service_account_iam_member" "pipeline_wif_binding" {
  service_account_id = google_service_account.pipeline.name
  role               = "roles/iam.workloadIdentityUser"
  # subject is set by ADO as: sc://<org>/<project>/<service-connection-name>
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.ado.name}/attribute.aud/api://AzureADTokenExchange"
}

# ── Outputs for pipeline configuration ────────────────────────────────────────
output "wif_pool_name" {
  description = "Full resource name of the WIF pool — used in pipeline credential config"
  value       = google_iam_workload_identity_pool.ado.name
}

output "wif_provider_name" {
  description = "Full resource name of the WIF provider — used in pipeline credential config"
  value       = google_iam_workload_identity_pool_provider.ado.name
}

output "pipeline_sa_email" {
  description = "Pipeline service account email — used in pipeline credential config"
  value       = google_service_account.pipeline.email
}
