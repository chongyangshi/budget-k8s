locals {
  // GCP IAP ranges are fixed public ranges as documented here:
  // https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule
  gcp_iap_ranges = ["35.235.240.0/20"]
}

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

// Hosts ingress load-balancing GCE instances
resource "google_compute_subnetwork" "ingress" {
  name = "ingress"

  ip_cidr_range            = "192.168.0.0/24"
  region                   = var.project_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = var.project_id

  // Logging is not enabled at network level to avoid
  // Stackdriver costs associated with flow logs.
}

// Hosts the VPC-native network used by the managed Kubernetes cluster and its 
// pods and services
resource "google_compute_subnetwork" "kubernetes" {
  name = "kubernetes"

  ip_cidr_range            = "10.200.0.0/17"
  region                   = var.project_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.200.128.0/18"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.200.192.0/18"
  }

  // Logging is not enabled at network level to avoid
  // Stackdriver costs associated with flow logs.
}
