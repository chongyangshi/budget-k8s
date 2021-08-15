// For ingress we use a GCE instance on non-preemptible mode with a public IP.
// We don't use a load balancer due to its standing cost in contrast with the
// lack of high-availability guarantees of personal projects. 
// We also can't launch this instance with an instance group 
// as we will not be able to attach a fixed static IP for DNS.

locals {
  traefik_config_file = templatefile("${path.module}/instance_resources/traefik.yaml", {
    acme_account_email    = var.ingress_acme_account_email,
    traefik_service_token = data.kubernetes_secret.traefik_service_token.data.token,
  })

  traefik_service_file = file("${path.module}/instance_resources/traefik.service")
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

resource "google_compute_instance" "default" {
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
    network    = var.vpc_name
    subnetwork = "ingress"

    access_config {
      nat_ip       = google_compute_address.ingress_instance_ip.address
      network_tier = "STANDARD"
    }
  }


  metadata_startup_script = templatefile("${path.module}/instance_resources/bootstrap.sh", {
    traefik_version      = var.ingress_traefik_version,
    traefik_config_file  = local.traefik_config_file,
    traefik_service_file = local.traefik_service_file,
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

  deletion_protection = true

  depends_on = [
    google_kms_crypto_key_iam_policy.ingress
  ]
}
