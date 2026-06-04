locals {
  # Naming convention mirrors Azure: <project_acronym>-<resource>-<environment>
  prefix = "${var.project_acronym}-${var.environment}"

  # GKE Standard
  gke_cluster_name = "${var.project_acronym}-gke-${var.environment}"
  gke_node_sa_name = "${var.project_acronym}-sa-gke-${var.environment}"

  # GKE Autopilot
  gke_autopilot_name    = "${var.project_acronym}-gke-ap-${var.environment}"
  subnet_gke_autopilot  = "${var.project_acronym}-snet-gke-ap-${var.environment}"

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

  # Cloud Data Fusion — equivalent of Azure Data Factory
  data_fusion_name = "${var.project_acronym}-df-${var.environment}"

  # Cloud Pub/Sub — equivalent of Azure Event Hub
  pubsub_topic_name        = "${var.project_acronym}-topic-${var.environment}"
  pubsub_subscription_name = "${var.project_acronym}-sub-${var.environment}"

  # BigQuery — equivalent of Azure Synapse Analytics
  bigquery_dataset_id = "${var.project_acronym}_bq_${var.environment}"

  # Cloud Functions v2 — equivalent of Azure Function App
  cf_function_name      = "${var.project_acronym}-func-${var.environment}"
  cf_source_bucket_name = "${var.project_acronym}-func-src-${var.environment}-${var.gcp_project_id}"
  cf_sa_name            = "${var.project_acronym}-sa-func-${var.environment}"

  # Firestore — equivalent of Azure Cosmos DB
  firestore_database_id = "${var.project_acronym}-db-${var.environment}"

  # Cloud Workflows — equivalent of Azure Logic Apps
  workflow_name    = "${var.project_acronym}-wf-${var.environment}"
  workflow_sa_name = "${var.project_acronym}-sa-wf-${var.environment}"

  # Vertex AI — equivalent of Azure AI Foundry
  vertex_ai_sa_name     = "${var.project_acronym}-sa-vai-${var.environment}"
  vertex_ai_bucket_name = "${var.project_acronym}-vai-${var.environment}-${var.gcp_project_id}"

  # GCP labels — equivalent of Azure common_tags (values must be lowercase)
  common_labels = {
    project     = lower(var.project)
    environment = var.environment
    region      = var.region
    owner       = replace(lower(var.owner), " ", "-")
    managed_by  = "terraform"
  }
}
