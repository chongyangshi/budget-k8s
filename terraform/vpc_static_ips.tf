// Static IP address attached to the VPC's Cloud NAT gateway
resource "google_compute_address" "nat_gateway_ip" {
  name = "${var.vpc_name}-nat-ip"

  address_type = "EXTERNAL"
  region       = var.project_region
  project      = var.project_id
}

// Static IP address attached to the ingress load-balancing instance
resource "google_compute_address" "ingress_instance_ip" {
  name = "ingress"

  address_type = "EXTERNAL"
  region       = var.project_region
  project      = var.project_id
}
