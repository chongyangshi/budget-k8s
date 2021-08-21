locals {
  sans = length(var.service_hostnames) > 1 ? slice(var.service_hostnames, 1, length(var.service_hostnames)) : []

  tls_annotations = {
    "kubernetes.io/ingress.class"                             = "traefik"
    "traefik.ingress.kubernetes.io/router.entrypoints"        = "websecure"
    "traefik.ingress.kubernetes.io/router.tls"                = "true"
    "traefik.ingress.kubernetes.io/router.tls.certresolver"   = "default"
    "traefik.ingress.kubernetes.io/router.tls.domains.0.main" = var.service_hostnames[0]
    "traefik.ingress.kubernetes.io/router.tls.domains.0.sans" = length(local.sans) > 0 ? join(",", local.sans) : null
  }

  no_tls_annotations = {
    "kubernetes.io/ingress.class"                      = "traefik"
    "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    "traefik.ingress.kubernetes.io/router.tls"         = "false"
  }

  // If backend service in the same namespace we route Traefik packets straight to the 
  // service, else we route them to the proxy created.
  requires_service_proxy = var.service_namespace == var.ingress_namespace ? false : true

  service_proxy_name   = var.ingress_name != "" ? "${var.ingress_name}-proxy" : "${var.service_name}-proxy"
  backend_service_name = local.requires_service_proxy ? local.service_proxy_name : var.service_name
}

resource "kubernetes_ingress" "service" {
  metadata {
    name      = var.ingress_name != "" ? var.ingress_name : var.service_name
    namespace = var.ingress_namespace

    annotations = var.traefik_terminate_tls ? local.tls_annotations : local.no_tls_annotations
  }

  spec {
    backend {
      service_name = local.backend_service_name
      service_port = var.service_port
    }

    dynamic "rule" {
      for_each = var.service_hostnames
      content {
        host = rule.value
        http {
          path {
            backend {
              service_name = local.backend_service_name
              service_port = var.service_port
            }

            path = "/"
          }
        }
      }
    }
  }
}

