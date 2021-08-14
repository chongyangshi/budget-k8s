terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.79"
    }
  }
}

data "google_project" "project" {
  project_id = var.project_id
}
