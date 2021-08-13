// Allows external traffic to hit the ingress load balancing instance with
// a public IP on expected ingress ports
resource "google_compute_firewall" "allow_external_ingress" {
  name = "allow-external-ingress"

  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  project   = var.project_id

  allow {
    protocol = "tcp"
    ports    = var.external_ingress_tcp_ports
  }

  dynamic "allow" {
    for_each = length(var.external_ingress_udp_ports) > 0 ? [1] : []
    content {
      protocol = "udp"
      ports    = var.external_ingress_udp_ports
    }
  }

  target_tags = ["ingress"]
}

// Allows SSH traffic to all instances via the GCP Identity-Aware Proxy
// (IAP) ranges
resource "google_compute_firewall" "allow_from_iap" {
  name = "allow-from-iap"

  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  project   = var.project_id

  allow {
    protocol = "tcp"
    ports    = 22
  }

  source_ranges = local.gcp_iap_ranges
}

// Allows traffic forwarded from the ingress instance to reach arbitrary
// TCP or UDP Node Ports on Kubernetes nodes
resource "google_compute_firewall" "allow_ingress" {
  name = "allow-ingress"

  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  project   = var.project_id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = [google_compute_subnetwork.ingress.ip_cidr_range]
}

// Allows all instances to egress to the internet. We choose not to explicitly
// allowlist egress on a GCP network level as there is no economical option to
// run a hostname-based egress firewall before or at the point of NAT.
resource "google_compute_firewall" "allow_egress_to_internet" {
  name = "allow-egress-to-internet"

  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  project   = var.project_id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  destination_ranges = ["0.0.0.0/0"]
}
