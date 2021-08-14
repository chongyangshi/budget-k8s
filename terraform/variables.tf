variable "project_id" {
  type        = string
  description = "Unique ID of the GCP project, not the abbreviation"
}

variable "project_region" {
  type        = string
  description = "Region in which the zonal GCP cluster and associated resources will be created"
  default     = "europe-west2"
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the Cloud Storage bucket storing terraform state"
}

variable "state_bucket_region" {
  type        = string
  description = "Region of the Cloud Storage bucket storing terraform state, for example US or EU"
  default     = "EU"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to be created"
  default     = "budget-k8s"
}

variable "cluster_zone" {
  type        = string
  description = "Zone within the region in which the zonal GCP cluster and nodes will be created"
  default     = "a"
}

variable "external_ingress_tcp_ports" {
  type        = list(string)
  description = "List of TCP ports (in string literals) allowed to reach the ingress instances."
  default     = ["80", "443"]
}

variable "external_ingress_udp_ports" {
  type        = list(string)
  description = "List of UDP ports (in string literals) allowed to reach the ingress instances, if any"
  default     = []
}

variable "external_control_plane_access_ranges" {
  type        = list(string)
  description = "List of external IP address ranges allowed to access the GKE Kubernetes control plane"
  default     = []
}

variable "node_pools_first_instance_type" {
  type        = string
  description = "GCE instance type used for the first preemptible node pool"
  default     = "n2d-standard-2"
}

variable "node_pools_first_instance_count" {
  type        = number
  description = "Number of desired GCE instances provisioned for the first preemptible node pool"
  default     = 2
}

variable "node_pools_second_instance_type" {
  type        = string
  description = "GCE instance type used for the second preemptible node pool"
  default     = "n2d-standard-4"
}

variable "node_pools_second_instance_count" {
  type        = number
  description = "Number of desired GCE instances provisioned for the second preemptible node pool"
  default     = 1
}

variable "node_ephemeral_disk_size_gb" {
  type        = number
  description = "Number of GiBs in size the ephemeral disks of the node should run with"
  default     = 50
}
