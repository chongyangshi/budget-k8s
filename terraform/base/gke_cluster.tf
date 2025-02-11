locals {
  master_ip_range = "172.16.0.0/28"
}

// We run the GKE cluster and all its nodes in a fixed zone within the project
// region, which allows us to benefit from the waiving of the monthly cluster
// management fee for the first zonal cluster in the billing account, as well
// as avoidance of the traffic cost for cross-availability-zone traffic. This
// is at the cost of resiliency as our cluster will be offline entirely if
// the specific availability zone goes down in a rare event.
resource "google_container_cluster" "cluster" {
  name = "${var.vpc_name}-cluster"

  project  = var.project_id
  provider = google-beta
  depends_on = [
    google_kms_crypto_key_iam_policy.cluster,
  ]

  location       = "${var.project_region}-${var.cluster_zone}"
  node_locations = [] // No other zones

  // We run fixed-sized preemptibl node groups with manual scaling
  // to make costs predictable.
  cluster_autoscaling {
    enabled = false
  }

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.cluster.id
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  monitoring_config {
    managed_prometheus {
      enabled = false
    }
  }

  // We do not use binary authorization due to its additional cost and 
  // relatively limited benefit in the personal context of usage.

  network         = google_compute_network.vpc.self_link
  subnetwork      = google_compute_subnetwork.kubernetes.self_link
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  master_authorized_networks_config {
    // Allow access from ingress instances to the control plane for
    // information on ingress endpoints
    cidr_blocks {
      cidr_block   = google_compute_subnetwork.ingress.ip_cidr_range
      display_name = "ingress-private"
    }

    // Allow access from user-supplied IP ranges
    dynamic "cidr_blocks" {
      for_each = var.external_control_plane_access_ranges
      content {
        cidr_block   = cidr_blocks.value
        display_name = "additional-control-plane-access"
      }
    }
  }

  private_cluster_config {
    // Run worker nodes without public IPs
    enable_private_nodes = true

    // Misnamed, when false allows both public (under authorized networks) and
    // private endpoint access
    enable_private_endpoint = false

    master_ipv4_cidr_block = local.master_ip_range
  }

  release_channel {
    channel = "REGULAR"
  }

  network_policy {
    enabled = true
  }

  addons_config {
    http_load_balancing {
      // We use an external load-balancing instance to reduce the cost of
      // load balancers
      disabled = true
    }

    network_policy_config {
      // We want network policy support
      disabled = false
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  // Not much use for a personal project -- only one user will hold
  // permission to launch workloads from new specifications in general.
  pod_security_policy_config {
    enabled = false
  }

  enable_shielded_nodes = true

  // Per Terraform documentation:
  // We can't create a cluster with no node pool defined, but we want to only use
  // separately managed node pools. So we create the smallest possible default
  // node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  lifecycle {
    ignore_changes = [
      // For compatability with existing clusters, as this cannot be changed after
      // cluster creation.
      monitoring_config,
    ]
  }
}

// We run two preemptible node pools to provide a small amount of resistance to 
// preemptions and simutaneous terminations.
resource "google_container_node_pool" "preemptible_nodes_first_pool" {
  name = "${var.vpc_name}-cluster-preemptible-1"

  project  = var.project_id
  provider = google-beta
  location = "${var.project_region}-${var.cluster_zone}"

  cluster = google_container_cluster.cluster.name

  // All nodes run the same availability zone as the control plane to limit
  // inter-AZ traffic cost
  node_locations = ["${var.project_region}-${var.cluster_zone}"]
  node_count     = var.node_pools_first_instance_count

  node_config {
    preemptible  = true
    machine_type = var.node_pools_first_instance_type

    disk_size_gb = var.node_ephemeral_disk_size_gb
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    labels = {
      node_pool = "preemptible-1"
    }

    boot_disk_kms_key = google_kms_crypto_key.cluster.id

    // For some reason, even if the service account has read-only permissions
    // on the storage bucket for GCR, the nodes still can't access it without
    // scopes for devstorage.read_only also being set.
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    service_account = google_service_account.cluster.email

    // We do not use gVisor with sandbox_config, as it will turn off
    // hyper-threading (HT) and thus cutting our usable CPU resource 
    // in half. This measure mitigates cross-VM attacks due to hardware 
    // HT vulnerabilities but the cost to mitigate this risk isn't
    // justifiable for personal projects. To turn it on anyway, use:
    //
    // sandbox_config {
    //   sandbox_type = "gvisor"  
    // }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    linux_node_config {
      cgroup_mode = "CGROUP_MODE_V2"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 1
  }
}

resource "google_container_node_pool" "preemptible_nodes_second_pool" {
  name = "${var.vpc_name}-cluster-preemptible-2"

  project  = var.project_id
  provider = google-beta
  location = "${var.project_region}-${var.cluster_zone}"

  cluster = google_container_cluster.cluster.name

  // All nodes run the same availability zone as the control plane to limit
  // inter-AZ traffic cost
  node_locations = ["${var.project_region}-${var.cluster_zone}"]
  node_count     = var.node_pools_second_instance_count

  node_config {
    preemptible  = true
    machine_type = var.node_pools_second_instance_type

    disk_size_gb = var.node_ephemeral_disk_size_gb
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    labels = {
      node_pool = "preemptible-2"
    }

    boot_disk_kms_key = google_kms_crypto_key.cluster.id

    // For some reason, even if the service account has read-only permissions
    // on the storage bucket for GCR, the nodes still can't access it without
    // scopes for devstorage.read_only also being set.
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    service_account = google_service_account.cluster.email

    // We do not use gVisor with sandbox_config, as it will turn off
    // hyper-threading (HT) and thus cutting our usable CPU resource 
    // in half. This measure mitigates cross-VM attacks due to hardware 
    // HT vulnerabilities but the cost to mitigate this risk isn't
    // justifiable for personal projects. To turn it on anyway, use:
    //
    // sandbox_config {
    //   sandbox_type = "gvisor"  
    // }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    linux_node_config {
      cgroup_mode = "CGROUP_MODE_V2"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 1
  }
}

resource "google_logging_project_exclusion" "cluster_container_logs" {
  count   = var.cluster_container_logs_ingested ? 0 : 1
  name    = "cluster-container-logs-excluded"
  project = data.google_project.project.number

  description = "Do not ingest cluster container logs into Cloud Logging."

  filter = "resource.type = k8s_container AND resource.labels.cluster_name=\"${google_container_cluster.cluster.name}\""
}

output "gke_cluster_endpoint" {
  value = google_container_cluster.cluster.endpoint
}

output "gke_cluster_ca_cert" {
  value = google_container_cluster.cluster.master_auth.0.cluster_ca_certificate
}
