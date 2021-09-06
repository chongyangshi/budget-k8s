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
    ports    = ["22"]
  }

  source_ranges = local.gcp_iap_ranges
}

// Allows traffic forwarded from the ingress instance to reach arbitrary
// TCP or UDP Node Ports on Kubernetes nodes. This is because we cannot
// predict what service_port will be specified in the ingress layer via
// ingress/gke_ingresses.tf. This does present an internal network 
// security risk. 
// To prevent Traefik from accesing container ports on Pods not intended 
// to be accessible via the ingress instance, there are two options:
// (1) Set up a default network policy for each non-ingress namespace
//     preventing cross-namespace traffic unless allowlisted by more 
//     specific NetworkPolicies of workloads accepting such traffic.
// (2) Run all services in namespaces other than the `ingress` 
//     namespace, and ensure the backend service ports do not overlap
//     with the external_ingress_tcp_ports or external_ingress_udp_ports.
//     This way only service proxies generated for these backend services
//     will bhave ports accessible by the Traefik Proxy.
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
