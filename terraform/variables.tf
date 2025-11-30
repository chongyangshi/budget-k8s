variable "project_id" {
  type        = string
  description = "Unique ID of the GCP project, not the abbreviation"
}

variable "project_region" {
  type        = string
  description = "Region in which the zonal GCP cluster and associated resources will be created"
  default     = "europe-west2"
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

variable "cluster_container_logs_ingested" {
  type        = bool
  description = "Whether cluster container logs should be ingested to Cloud Logs."
  default     = false
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

variable "ingress_namespace_tcp_ports" {
  type        = list(string)
  description = "All TCP ports (in string literals) which are targetPorts / container ports of any ClusterIP Services accepting ingress traffic, or nodePorts of any NodePort Services accepting ingress traffic. Only needs to be set if running in the ingress namespace (not recommended), as service proxy Pods will forward traffic from Traefik Proxy automatically."
  default     = []
}

variable "ingress_namespace_udp_ports" {
  type        = list(string)
  description = "All UDP ports (in string literals) which are targetPorts / container ports of any ClusterIP Services accepting ingress traffic, or nodePorts of any NodePort Services accepting ingress traffic. Only needs to be set if running in the ingress namespace (not recommended), as service proxy Pods will forward traffic from Traefik Proxy automatically."
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

variable "ingress_ephemeral_disk_size_gb" {
  type        = number
  description = "Number of GiBs in size the ephemeral disks of the ingress load-balancing instance should run with"
  default     = 10
}

variable "ingress_instance_type" {
  type        = string
  description = "GCE instance type for the permanent ingress load-balancing instance with a public IP"
  default     = "e2-micro"
}

variable "ingress_image_type" {
  type        = string
  description = "GCE image type for the permanent ingress load-balancing instance with a public IP"
  default     = "debian-cloud/debian-12"
}

variable "ingress_acme_account_email" {
  type        = string
  description = "The Let's Encrypt account email address used for issuing TLS certificates for your ingress hosts by DNS name"
  default     = "you@example.com"
}

variable "ingress_traefik_version" {
  type        = string
  description = "The version ID (e.g. v2.10.0) of Traefik ingress proxy to be installed in the ingress load-balancing instance"
  default     = "v2.10.0"
}

variable "kms_key_rotation_period_seconds" {
  type        = number
  description = "If set to a non-zero value, number of seconds (e.g. 7776000 for 90 days) for Cloud KMS to automatically rotate keys."
  default     = 0
}
