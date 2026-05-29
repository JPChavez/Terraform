# ── Cloud Workflows — equivalent of Azure Logic Apps ─────────────────────────

resource "google_service_account" "workflow" {
  account_id   = local.workflow_sa_name
  display_name = "Cloud Workflows SA — ${local.prefix}"
  project      = var.gcp_project_id
}

# Allow the workflow SA to write logs
resource "google_project_iam_member" "workflow_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_workflows_workflow" "main" {
  name            = local.workflow_name
  region          = var.region
  project         = var.gcp_project_id
  service_account = google_service_account.workflow.email

  # Minimal placeholder workflow — replace with real steps via CI/CD or direct update
  source_contents = <<-EOT
    main:
      steps:
        - init:
            call: sys.log
            args:
              text: "Workflow started"
              severity: INFO
        - finish:
            return: "OK"
  EOT

  labels = local.common_labels
}
