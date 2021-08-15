// Container registry for custom images used in the cluster
resource "google_container_registry" "cluster" {
  project  = var.project_id
  location = var.container_registry_region
}

// Allows the cluster service account to read images in the cluster
resource "google_storage_bucket_iam_member" "cluster_viewer" {
  bucket = google_container_registry.cluster.id
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cluster.email}"
}
