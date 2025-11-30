// KMS key ring for encrypting cluster secrets
resource "google_kms_key_ring" "cluster" {
  name     = "cluster"
  location = var.project_region
  project  = var.project_id
}

// KMS key for encrypting cluster secrets
resource "google_kms_crypto_key" "cluster" {
  name     = "cluster"
  key_ring = google_kms_key_ring.cluster.id

  // Managed key is not rotated periodically unless kms_key_rotation_period_seconds is set to non-zero.
  rotation_period = var.kms_key_rotation_period_seconds == 0 ? null : var.kms_key_rotation_period_seconds

  version_template {
    protection_level = "SOFTWARE"
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_iam_policy" "cluster_kms_access" {
  binding {
    role = "roles/cloudkms.cryptoOperator"

    members = [
      "serviceAccount:${google_service_account.cluster.email}",
      // The container engine robot must be allowed access to the secret as well 
      // for etcd database encryptions
      "serviceAccount:service-${data.google_project.project.number}@container-engine-robot.iam.gserviceaccount.com",
      // Disk encryption for node groups are operated with the compute engine
      // service account
      "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com",
    ]
  }
}

resource "google_kms_crypto_key_iam_policy" "cluster" {
  crypto_key_id = google_kms_crypto_key.cluster.id
  policy_data   = data.google_iam_policy.cluster_kms_access.policy_data
}
