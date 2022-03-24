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

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

// Requires pre-configuration with:
// gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>
provider "kubernetes" {
  config_path = "~/.kube/config"
}

// Provides project metadata information.
data "google_project" "project" {
  project_id = var.project_id
}
