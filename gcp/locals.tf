locals {
  # Naming convention mirrors Azure: <project_acronym>-<resource>-<environment>
  prefix = "${var.project_acronym}-${var.environment}"

  # GKE
  gke_cluster_name = "${var.project_acronym}-gke-${var.environment}"
  gke_node_sa_name = "${var.project_acronym}-sa-gke-${var.environment}"

  # Artifact Registry — equivalent of ACR
  ar_repository_id = "${var.project_acronym}-ar-${var.environment}"

  # Cloud KMS — equivalent of Key Vault + CMK keys + Disk Encryption Set
  kms_keyring_name     = "${var.project_acronym}-kr-${var.environment}"
  kms_key_gke_name     = "key-gke-${local.prefix}"
  kms_key_storage_name = "key-storage-${local.prefix}"
  kms_key_ar_name      = "key-ar-${local.prefix}"

  # Cloud Storage — globally unique: include project_id as suffix
  gcs_bucket_name = "${var.project_acronym}-gcs-${var.environment}-${var.gcp_project_id}"

  # VPC
  vpc_name      = "${var.project_acronym}-vpc-${var.environment}"
  subnet_gke    = "${var.project_acronym}-snet-gke-${var.environment}"
  subnet_system = "${var.project_acronym}-snet-system-${var.environment}"

  # GCP labels — equivalent of Azure common_tags (values must be lowercase)
  common_labels = {
    project     = lower(var.project)
    environment = var.environment
    region      = var.region
    owner       = replace(lower(var.owner), " ", "-")
    managed_by  = "terraform"
  }
}
