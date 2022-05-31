# GKE will not have a long enough opportunity to drain the node before
# a preemptible instance is shutdown (rarely because of capacity situation
# and far more often due to the 24-hour limit). This will result in a lot
# of pods in Terminated / failed status:
#
# status:
#   message: Pod was terminated in response to imminent node shutdown.
#   phase: Failed
#   reason: Terminated
#   startTime: "2022-05-26T11:54:20Z"
#
# To avoid these from cramping up the API responses, this CronJob 
# periodically cleans them up cluster-wide.
resource "kubernetes_service_account" "terminated_pods_janitor" {
  metadata {
    name      = "terminated-pods-janitor"
    namespace = "kube-public"
  }
}

resource "kubernetes_cluster_role" "terminated_pods_janitor" {
  metadata {
    name = "terminated-pods-janitor"
  }

  // Read and delete access to all pods
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "delete"]
  }

  // Read-only access to namespaces
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "terminated_pods_janitor" {
  metadata {
    name = "terminated-pods-janitor"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.terminated_pods_janitor.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.terminated_pods_janitor.metadata.0.name
    namespace = "kube-public"
  }
}

resource "kubernetes_cron_job" "terminated_pods_janitor" {
  metadata {
    name      = "terminated-pods-janitor"
    namespace = "kube-public"
  }
  spec {
    concurrency_policy            = "Replace"
    failed_jobs_history_limit     = 5
    schedule                      = "30 5 * * *"
    starting_deadline_seconds     = 300
    successful_jobs_history_limit = 5

    job_template {
      metadata {
        labels = {
          app = "terminated-pods-janitor"
        }
      }
      spec {
        active_deadline_seconds    = 3600
        backoff_limit              = 2
        completions                = 1
        parallelism                = 1
        ttl_seconds_after_finished = 3600
        template {
          metadata {
            labels = {
              app = "terminated-pods-janitor"
            }
          }
          spec {
            container {
              name = "terminated-pods-janitor"

              // There isn't a nice "official" kubectl Docker image
              // maintained by anyone, but VMWare owns Bitnami, and
              // DockerHub has stamped their account with "verified",
              // so this is probably the best option as an external
              // dependency..
              image = "bitnami/kubectl:latest"
              command = [
                "/bin/bash",
              ]
              args = [
                "-c",
                "kubectl get namespaces -o name | sed -e 's#^namespace/##' | while read -r namespace; do kubectl get pods --field-selector 'status.phase=Failed' -o name -n $namespace | xargs -r kubectl delete -n $namespace; done",
              ]

              resources {
                limits = {
                  cpu    = "100m"
                  memory = "200Mi"
                }
                requests = {
                  cpu    = "50m"
                  memory = "100Mi"
                }
              }
            }

            service_account_name = kubernetes_service_account.terminated_pods_janitor.metadata.0.name
          }
        }
      }
    }
  }
}
