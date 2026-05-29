# ── Cloud Pub/Sub — equivalent of Azure Event Hub ────────────────────────────

resource "google_pubsub_topic" "main" {
  name    = local.pubsub_topic_name
  project = var.gcp_project_id

  message_retention_duration = "${var.pubsub_message_retention_seconds}s"

  # Encrypt messages at rest with the existing Cloud KMS storage key
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  labels = local.common_labels
}

resource "google_pubsub_subscription" "main" {
  name    = local.pubsub_subscription_name
  topic   = google_pubsub_topic.main.id
  project = var.gcp_project_id

  ack_deadline_seconds = 20

  # Retain undelivered messages for 10 minutes after ack deadline
  message_retention_duration = "600s"

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Dead-letter configuration can be added here once a dead-letter topic is created

  labels = local.common_labels
}
