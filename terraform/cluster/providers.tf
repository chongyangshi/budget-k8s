terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.79"
    }
  }
}

// Provides project metadata information.
data "google_project" "project" {
  project_id = var.project_id
}
