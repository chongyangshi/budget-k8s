// TODO: middlewares

variable "ingress_namespace" {
  type        = string
  description = "Namespace watched by Traefik for routing ingress traffic"
  default     = "ingress"
}

variable "ingress_name" {
  type        = string
  description = "A unique name for this ingress, defaults to service_name if empty; fill this if multiple ingresses are created for the same service"
  default     = ""
}

variable "service_hostnames" {
  type        = list(string)
  description = "A list of hostnames (e.g. example.com, www.example.com) for which this service should accept ingress traffic"
}

variable "service_name" {
  type        = string
  description = "Name of the Kubernetes Service receiving ingress traffic for the hostname from Traefik"
}

variable "service_namespace" {
  type        = string
  description = "Namespace of the Kubernetes Service receiving ingress traffic for the hostname from Traefik, if different from ingress_namespace an nginx reverse proxy will be set up for cross-namespace forwarding"
}

variable "service_port" {
  type        = number
  description = "Service Port (not the Container Port which may be different) for the Kubernetes Service receiving ingress traffic"
  default     = 80
}

variable "service_traefik_middlewares" {
  type        = list(string)
  description = "A list of Traefik applicable middlewares for this service (e.g. 'testBasicAuth@file'). All middleware refeenced should have been configured for the ingress instance in terraform/ingress/instance_resources/middlewares.yaml"
  default     = []
}

variable "service_protocol" {
  type        = string
  description = "Protocol for the Kubernetes Service receiving ingress traffic, note that while our service proxy supports both TCP and UDP, normally only HTTP/HTTPS TCP will be forwarded by Traefik"
  default     = "TCP"
}

variable "service_proxy_image_uri" {
  type        = string
  description = "Docker image URI for the nginx service proxy, defaults to nginx:stable from DockerHub, set if vendoring"
  default     = "nginx:stable"
}

variable "service_proxy_replicas" {
  type        = number
  description = "Number of Pods to provision for the nginx service proxy"
  default     = 2
}

variable "service_proxy_cpu_request" {
  type        = string
  description = "CPU resource request to provision for the nginx service proxy, in Kubernetes CPU resource format (e.g. 200m)"
  default     = "50m"
}

variable "service_proxy_cpu_limit" {
  type        = string
  description = "CPU resource limit to provision for the nginx service proxy, in Kubernetes CPU resource format (e.g. 400m)"
  default     = "200m"
}

variable "service_proxy_memory_request" {
  type        = string
  description = "Memory resource request to provision for the Nginx service proxy, in Kubernetes memory resource format (e.g. 100Mi)"
  default     = "64Mi"
}

variable "service_proxy_memory_limit" {
  type        = string
  description = "Memory resource limit to provision for the Nginx service proxy, in Kubernetes memory resource format (e.g. 200Mi)"
  default     = "256Mi"
}

variable "traefik_terminate_tls" {
  type        = bool
  description = "Whether Traefik should terminate TLS for the receiving service with Let's Encrypt ACME, rather than the service terminating its own TLS"
  default     = true
}
