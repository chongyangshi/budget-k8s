# Because Traefik implements its Kubernetes API client with reflect, it
# requires the ability to list all secrets in specific namespaces it
# watches for new ingress resources in, and stubbornly refuses to provide
# a config to turn secret access off if the user does not want to load any
# TLS certificates: https://github.com/traefik/traefik/issues/7097; we
# have to set up a namespace dedicated to ingress services in the cluster
# for traefik to access secrets in, which is best practice in any case.
resource "kubernetes_namespace" "ingress" {
  metadata {
    labels = {
      name = "ingress"
    }

    name = "ingress"
  }

  depends_on = [
    google_container_cluster.cluster
  ]
}

resource "kubernetes_service_account" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "ingress"
  }

  depends_on = [
    google_container_cluster.cluster
  ]
}

// This exported service account token secret WILL appear in Terraform
// state, however it only allows reading service and ingresses and updating
// their statuses across the cluster, and only reading secrets in the 
// namespace for ingress services only. Therefore it is reasonably safe
// to end up in Terraform remote state.
data "kubernetes_secret" "traefik_service_token" {
  metadata {
    name = kubernetes_service_account.traefik.default_secret_name
  }
}
