// For ingress we use a GCE instance on non-preemptible mode with a public IP.
// We don't use a load balancer due to its standing cost in contrast with the
// lack of high-availability guarantees of personal projects. 
// We also can't launch this instance with an instance group 
// as we will not be able to attach a fixed static IP for DNS.

locals {
  traefik_config_file = base64encode(templatefile("${path.module}/instance_resources/traefik.yaml", {
    acme_account_email    = var.ingress_acme_account_email,
    traefik_service_token = data.kubernetes_secret.traefik_service_token.data.token,
  }))

  traefik_logrotate_file = filebase64("${path.module}/instance_resources/logrotate.conf")

  traefik_service_file = filebase64("${path.module}/instance_resources/traefik.service")

  traefik_middlewares_file = fileexists("${path.module}/instance_resources/middlewares_override.yaml") ? filebase64("${path.module}/instance_resources/middlewares_override.yaml") : filebase64("${path.module}/instance_resources/middlewares.yaml")
}

// Static IP address attached to the ingress load-balancing instance
resource "google_compute_address" "ingress_instance_ip" {
  name = "ingress"

  address_type = "EXTERNAL"
  region       = var.project_region
  project      = var.project_id

  // We avoid expensive transit through some Asian regions using
  // Google's backbone network in order to limit egress cost.
  network_tier = "STANDARD"
}

data "google_compute_subnetwork" "ingress" {
  name    = "ingress"
  project = var.project_id
  region  = var.project_region
}

data "google_container_cluster" "cluster" {
  name     = "${var.vpc_name}-cluster"
  location = format("%s-%s", var.project_region, var.cluster_zone)
  project  = var.project_id
}

resource "google_compute_instance" "ingress" {
  name         = "ingress"
  machine_type = var.ingress_instance_type
  zone         = format("%s-%s", var.project_region, var.cluster_zone)
  project      = var.project_id

  allow_stopping_for_update = true

  // Network tag matching the firewall rules for ingress ports
  tags = ["ingress"]

  boot_disk {
    auto_delete = true

    initialize_params {
      image = var.ingress_image_type
      size  = var.ingress_ephemeral_disk_size_gb
      type  = "pd-standard"
    }

    kms_key_self_link = google_kms_crypto_key.ingress.self_link
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.ingress.self_link

    access_config {
      nat_ip       = google_compute_address.ingress_instance_ip.address
      network_tier = "STANDARD"
    }
  }


  metadata_startup_script = templatefile("${path.module}/instance_resources/bootstrap.sh", {
    traefik_version          = var.ingress_traefik_version,
    traefik_config_file      = local.traefik_config_file,
    traefik_service_file     = local.traefik_service_file,
    traefik_middlewares_file = local.traefik_middlewares_file,
    traefik_logrotate_conf   = local.traefik_logrotate_file,
    gke_control_plane_ca     = data.google_container_cluster.cluster.master_auth.0.cluster_ca_certificate,
  })

  service_account {
    email  = google_service_account.ingress.email
    scopes = []
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  scheduling {
    preemptible         = false
    on_host_maintenance = "MIGRATE"
    automatic_restart   = true
  }

  // This instance is mortal (the IP is not) and can be 
  // deleted and recreated at any time, at a cost of a short
  // period of ingress being unavailable.
  deletion_protection = false

  depends_on = [
    google_kms_crypto_key_iam_policy.ingress
  ]
}

output "public_ingress_ip" {
  description = "Public ingress IP for Traefik ingress load-balancer, which fronts cluster Ingresses"
  value       = google_compute_address.ingress_instance_ip.address
}