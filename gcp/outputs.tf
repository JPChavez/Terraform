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
