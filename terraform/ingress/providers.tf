terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.79"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  #host                   = var.cluster_endpoint
  #cluster_ca_certificate = base64decode(var.cluster_ca_cert)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["container", "clusters", "get-credentials", var.vpc_name + "-cluster", "--zone", var.project_region + "-" + var.cluster_zone, "--project", var.project_id]
    command     = "gcloud"
  }
}

// Provides project metadata information.
data "google_project" "project" {
  project_id = var.project_id
}
