// Because Traefik implements its Kubernetes API client with reflect, it
// requires the ability to list all secrets in specific namespaces it
// watches for new ingress resources in, and stubbornly refuses to provide
// a config to turn secret access off if the user does not want to load any
// TLS certificates: https://github.com/traefik/traefik/issues/7097; we
// have to set up a namespace dedicated to ingress services in the cluster
// for traefik to access secrets in, which is best practice in any case.
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
    namespace = kubernetes_namespace.ingress.metadata.0.name
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

resource "kubernetes_cluster_role" "traefik" {
  metadata {
    name = "traefik"
  }

  // Read access to exposed services and endpoints 
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }
  
  // Read access to ingresses in the new API class
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "ingressclasses"]
    verbs      = ["get", "list", "watch"]
  }

  // Read access to ingresses in the old API class
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses", "ingressclasses"]
    verbs      = ["get", "list", "watch"]
  }

  // Write access to ingress statuses in the new API class
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }

  // Write access to ingress statuses in the old API class
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }
}

resource "kubernetes_cluster_role_binding" "traefik" {
  metadata {
    name = "traefik"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.traefik.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.traefik.metadata.0.name
    namespace = kubernetes_namespace.ingress.metadata.0.name
  }
}

resource "kubernetes_role" "traefik" {
  metadata {
    name = "traefik-ingress-secret-access"
    namespace = kubernetes_namespace.ingress.metadata.0.name
  }

  // Allows read access to secrets in the ingress namespace only
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "traefik" {
  metadata {
    name = "traefik-ingress-secret-access"
    namespace = kubernetes_namespace.ingress.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.traefik.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.traefik.metadata.0.name
    namespace = kubernetes_namespace.ingress.metadata.0.name
  }
}