# ── GKE ──────────────────────────────────────────────────────────────────────

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "gke_cluster_id" {
  description = "Resource ID of the GKE cluster"
  value       = google_container_cluster.main.id
}

output "gke_kube_config_command" {
  description = "gcloud command to get GKE credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${var.region} --project ${var.gcp_project_id}"
}

output "gke_workload_identity_pool" {
  description = "Workload Identity pool — use this to bind GCP SAs to Kubernetes SAs"
  value       = "${var.gcp_project_id}.svc.id.goog"
}

output "gke_oidc_issuer_url" {
  description = "OIDC issuer URL for the GKE cluster (equivalent of AKS oidc_issuer_url)"
  value       = "https://container.googleapis.com/v1/projects/${var.gcp_project_id}/locations/${var.region}/clusters/${google_container_cluster.main.name}"
}

# ── GKE Autopilot ─────────────────────────────────────────────────────────────

output "gke_autopilot_cluster_name" {
  description = "Name of the GKE Autopilot cluster"
  value       = google_container_cluster.autopilot.name
}

output "gke_autopilot_cluster_id" {
  description = "Resource ID of the GKE Autopilot cluster"
  value       = google_container_cluster.autopilot.id
}

output "gke_autopilot_kube_config_command" {
  description = "gcloud command to fetch GKE Autopilot credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.autopilot.name} --region ${var.region} --project ${var.gcp_project_id}"
}

output "gke_autopilot_workload_identity_pool" {
  description = "Workload Identity pool for the GKE Autopilot cluster"
  value       = "${var.gcp_project_id}.svc.id.goog"
}

output "gke_autopilot_oidc_issuer_url" {
  description = "OIDC issuer URL for the GKE Autopilot cluster"
  value       = "https://container.googleapis.com/v1/projects/${var.gcp_project_id}/locations/${var.region}/clusters/${google_container_cluster.autopilot.name}"
}

# ── Artifact Registry ─────────────────────────────────────────────────────────

output "artifact_registry_name" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.name
}

output "artifact_registry_url" {
  description = "Docker pull/push URL for the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.main.repository_id}"
}

# ── Cloud KMS ─────────────────────────────────────────────────────────────────

output "kms_keyring_name" {
  description = "Name of the Cloud KMS key ring"
  value       = google_kms_key_ring.main.name
}

output "kms_keyring_id" {
  description = "Full resource ID of the Cloud KMS key ring"
  value       = google_kms_key_ring.main.id
}

# ── Cloud Storage ─────────────────────────────────────────────────────────────

output "gcs_bucket_name" {
  description = "Name of the GCS bucket"
  value       = google_storage_bucket.main.name
}

output "gcs_bucket_url" {
  description = "GCS bucket URL (gs://...)"
  value       = google_storage_bucket.main.url
}

# ── VPC ───────────────────────────────────────────────────────────────────────

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "vpc_id" {
  description = "Self-link of the VPC network"
  value       = google_compute_network.main.id
}

output "gke_subnet_name" {
  description = "Name of the GKE subnet"
  value       = google_compute_subnetwork.gke.name
}

# ── Cloud Data Fusion ─────────────────────────────────────────────────────────

output "data_fusion_name" {
  description = "Name of the Cloud Data Fusion instance"
  value       = google_data_fusion_instance.main.name
}

output "data_fusion_service_endpoint" {
  description = "Service endpoint URL of the Cloud Data Fusion instance"
  value       = google_data_fusion_instance.main.service_endpoint
}

# ── Cloud Pub/Sub ─────────────────────────────────────────────────────────────

output "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic"
  value       = google_pubsub_topic.main.name
}

output "pubsub_topic_id" {
  description = "Full resource ID of the Pub/Sub topic"
  value       = google_pubsub_topic.main.id
}

output "pubsub_subscription_name" {
  description = "Name of the Pub/Sub subscription"
  value       = google_pubsub_subscription.main.name
}

# ── BigQuery ──────────────────────────────────────────────────────────────────

output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset"
  value       = google_bigquery_dataset.main.dataset_id
}

output "bigquery_dataset_self_link" {
  description = "Self-link of the BigQuery dataset"
  value       = google_bigquery_dataset.main.self_link
}

# ── Cloud Functions v2 ────────────────────────────────────────────────────────

output "cloud_function_name" {
  description = "Name of the Cloud Function"
  value       = google_cloudfunctions2_function.main.name
}

output "cloud_function_uri" {
  description = "HTTPS trigger URI of the Cloud Function"
  value       = google_cloudfunctions2_function.main.service_config[0].uri
}

# ── Firestore ─────────────────────────────────────────────────────────────────

output "firestore_database_name" {
  description = "Name of the Firestore database"
  value       = google_firestore_database.main.name
}

# ── Cloud Workflows ───────────────────────────────────────────────────────────

output "workflow_name" {
  description = "Name of the Cloud Workflows workflow"
  value       = google_workflows_workflow.main.name
}

output "workflow_id" {
  description = "Full resource ID of the Cloud Workflows workflow"
  value       = google_workflows_workflow.main.id
}

# ── Vertex AI ─────────────────────────────────────────────────────────────────

output "vertex_ai_service_account_email" {
  description = "Email of the Vertex AI service account"
  value       = google_service_account.vertex_ai.email
}

output "vertex_ai_artifact_bucket" {
  description = "GCS bucket URL for Vertex AI model artifacts"
  value       = google_storage_bucket.vertex_ai.url
}
