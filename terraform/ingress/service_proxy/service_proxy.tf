// Forwards traffic cross-namespace to backend services using a
// light-weight nginx reverse proxy, in order to avoid Traefik
// having access to Secrets in the namespaces of these backend
// services.

data "kubernetes_service" "kube_dns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}

locals {
  // Service proxies always listen on the same container port 
  // that is not likely to be used by the user, to allow 
  // predictable a GCP firewall rule targeting their endpoints.
  container_port          = 18080
  container_port_protocol = var.service_protocol == "UDP" ? "${local.container_port} udp" : "${local.container_port}"
}

resource "kubernetes_config_map" "service_proxy" {
  count = local.requires_service_proxy ? 1 : 0

  metadata {
    name      = local.service_proxy_name
    namespace = var.ingress_namespace
  }

  data = {
    "nginx.conf" = templatefile("${path.module}/nginx_proxy.conf", {
      cluster_resolver        = data.kubernetes_service.kube_dns.spec.0.cluster_ip
      service_name            = var.service_name
      service_namespace       = var.service_namespace
      service_port            = var.service_port
      container_port_protocol = local.container_port_protocol
    })
  }
}

resource "kubernetes_service" "service_proxy" {
  count = local.requires_service_proxy ? 1 : 0

  metadata {
    name      = local.service_proxy_name
    namespace = var.ingress_namespace
  }

  spec {
    selector = kubernetes_deployment.service_proxy.0.spec.0.selector.0.match_labels

    session_affinity = "ClientIP"

    port {
      port        = var.service_port
      target_port = local.container_port
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "service_proxy" {
  count = local.requires_service_proxy ? 1 : 0

  metadata {
    name      = local.service_proxy_name
    namespace = var.ingress_namespace
    labels = {
      app       = local.service_proxy_name
      component = "service-proxy"
    }
  }

  spec {
    replicas = var.service_proxy_replicas

    selector {
      match_labels = {
        app       = local.service_proxy_name
        component = "service-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app       = local.service_proxy_name
          component = "service-proxy"
        }
      }

      spec {
        container {
          image = var.service_proxy_image_uri
          name  = "nginx-proxy"

          volume_mount {
            name       = "nginx-conf"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
            read_only  = true
          }

          volume_mount {
            name       = "run-volume"
            mount_path = "/var/run"
          }

          volume_mount {
            name       = "cache-volume"
            mount_path = "/var/cache/nginx"
          }

          resources {
            limits = {
              cpu    = var.service_proxy_cpu_limit
              memory = var.service_proxy_memory_limit
            }
            requests = {
              cpu    = var.service_proxy_cpu_request
              memory = var.service_proxy_memory_request
            }
          }

          // Nginx runtime run as user 101 by default in the 
          // DockerHub container builds
          security_context {
            run_as_group              = 101
            run_as_non_root           = true
            run_as_user               = 101
            read_only_root_filesystem = true
          }
        }

        security_context {
          run_as_group    = 101
          run_as_non_root = true
          run_as_user     = 101
        }

        volume {
          name = "nginx-conf"
          config_map {
            name = kubernetes_config_map.service_proxy.0.metadata.0.name
          }
        }

        volume {
          name = "run-volume"
          empty_dir {
            size_limit = "1Gi"
          }
        }

        volume {
          name = "cache-volume"
          empty_dir {
            size_limit = "2Gi"
          }
        }
      }
    }
  }
}
