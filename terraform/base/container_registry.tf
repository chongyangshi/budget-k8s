// Container registry for custom images used in the cluster
resource "google_container_registry" "cluster" {
  project  = var.project_id
  location = var.container_registry_region
}
