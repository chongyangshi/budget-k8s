terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.79"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.15"
    }
  }
}

// Provides project metadata information.
data "google_project" "project" {
  project_id = var.project_id
}
