// Service account with minimal permissions assigned to running the ingress instance
resource "google_service_account" "ingress" {
  // Account ID can be overridden for importing existing service accounts
  account_id   = "ingress"
  display_name = "ingress"
  project      = var.project_id
}

resource "google_project_iam_member" "ingress_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.ingress.email}"
}

resource "google_project_iam_member" "ingress_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.ingress.email}"
}

resource "google_project_iam_member" "ingress_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.ingress.email}"
}

resource "google_project_iam_member" "ingress_resource_metadata_viewer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.ingress.email}"
}
