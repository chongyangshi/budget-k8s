// Artifact registry for custom images used in the cluster
resource "google_artifact_registry_repository" "cluster" {
  provider = google-beta

  project       = var.project_id
  location      = var.project_region
  repository_id = "${var.vpc_name}-cluster"
  description   = "Shared artifact Registry repository for cluster of ${var.vpc_name}"
  format        = "DOCKER"
}
