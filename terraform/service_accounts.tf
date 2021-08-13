
// Service account with minimal permissions assigned to the cluster
resource "google_service_account" "cluster" {
  // Account ID can be overridden for importing existing service accounts
  account_id   = "cluster"
  display_name = "cluster"
  project      = var.project_id
}

data "google_iam_policy" "cluster" {
  binding {
    role = "roles/logging.logWriter"

    members = [
      google_service_account.cluster.email,
    ]
  }

  binding {
    role = "roles/monitoring.metricWriter"

    members = [
      google_service_account.cluster.email,
    ]
  }

  binding {
    role = "roles/monitoring.viewer"

    members = [
      google_service_account.cluster.email,
    ]
  }

  binding {
    role = "roles/stackdriver.resourceMetadata.writer"

    members = [
      google_service_account.cluster.email,
    ]
  }
}

resource "google_service_account_iam_policy" "cluster" {
  service_account_id = google_service_account.cluster.name
  policy_data        = data.google_iam_policy.cluster.policy_data
}
