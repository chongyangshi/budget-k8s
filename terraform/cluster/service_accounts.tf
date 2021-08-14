
// Service account with minimal permissions assigned to the cluster
resource "google_service_account" "cluster" {
  // Account ID can be overridden for importing existing service accounts
  account_id   = "cluster"
  display_name = "cluster"
  project      = var.project_id
}

resource "google_project_iam_member" "cluster_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_project_iam_member" "cluster_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_project_iam_member" "cluster_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_project_iam_member" "cluster_resource_metadata_viewer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.cluster.email}"
}
