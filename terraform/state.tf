terraform {
  backend "gcs" {
    bucket = var.state_bucket_name
    prefix = "budget-k8s/state"
  }
}
