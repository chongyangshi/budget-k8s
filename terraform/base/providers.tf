terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.20"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.20"
    }
  }
}

// Provides project metadata information.
data "google_project" "project" {
  project_id = var.project_id
}
