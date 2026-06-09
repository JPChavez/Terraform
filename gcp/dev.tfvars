gcp_project_id  = "project-db8078ea-74f1-4ed8-9f2"
region          = "us-central1"
environment     = "dev"
project         = "JProject"
project_acronym = "jp"
owner           = "Juan Pablo Chavez"

# Network — 10.0.x.x mirrors Azure dev (separate clouds, no overlap risk)
vpc_cidr           = "10.0.1.0/24"
system_subnet_cidr = "10.0.2.0/24"
pods_cidr          = "10.4.0.0/14"   # Secondary range for GKE pods
services_cidr      = "10.8.0.0/20"   # Secondary range for GKE services
master_cidr        = "172.16.0.0/28" # GKE control plane (/28 required)

# GKE Autopilot — GCP manages nodes and infrastructure; billing per pod
gke_private_cluster_enabled = false
gke_master_authorized_cidr  = "189.217.80.179/32"

# Storage — STANDARD + regional (equivalent of Azure ZRS)
gcs_storage_class = "STANDARD"
gcs_location      = "US-CENTRAL1"

# Cloud Data Fusion
data_fusion_edition = "DEVELOPER"

# Cloud Pub/Sub
pubsub_message_retention_seconds = 86400

# BigQuery
bigquery_dataset_location = "US"

# Cloud Functions v2
cloudfunctions_runtime       = "python311"
cloudfunctions_max_instances = 10

# Firestore
firestore_location_id = "us-central"
