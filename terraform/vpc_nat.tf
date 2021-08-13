resource "google_compute_router" "vpc_router" {
  name    = "${var.vpc_name}-router"
  region  = var.project_region
  project = var.vpc_name
  network = google_compute_network.vpc.id

  bgp {
    asn            = 64514
    advertise_mode = "CUSTOM"
  }
}

// A NAT Gateway for internet access from the entire VPC in region
resource "google_compute_router_nat" "vpc_nat_gateway" {
  name = "${var.vpc_name}-nat"

  router  = google_compute_router.vpc_router.name
  region  = var.project_region
  project = var.project_id

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.nat_gateway_ip.self_link]

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  // We also avoid logging NAT traffic in deference to
  // StackDriver costs
}
