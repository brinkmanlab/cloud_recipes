# TODO move to k8s folder

# https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

resource "kubernetes_namespace" "kube_dashboard" {
  depends_on = [module.eks.cluster_id]
  metadata {
    name = "kubernetes-dashboard"
  }
}

resource "kubernetes_service_account" "kube_dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
}

resource "kubernetes_service" "kube_dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app"                       = "kubernetes-dashboard"
      "kubernetes.io/cluster-service" = true
    }
  }
  spec {
    port {
      port        = 443
      target_port = 8443
    }
    selector = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
}

resource "kubernetes_secret" "kube_dashboard_certs" {
  metadata {
    name      = "kubernetes-dashboard-certs"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  type = "Opaque"
}

resource "kubernetes_secret" "kube_dashboard_csrf" {
  metadata {
    name      = "kubernetes-dashboard-csrf"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  type = "Opaque"
  data = {
    csrf = ""
  }
}

resource "kubernetes_secret" "kube_dashboard_key_holder" {
  metadata {
    name      = "kubernetes-dashboard-key-holder"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  type = "Opaque"
}

resource "kubernetes_config_map" "kube_dashboard_settings" {
  metadata {
    name      = "kubernetes-dashboard-settings"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
}

resource "kubernetes_role" "kube_dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  rule {
    # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs", "kubernetes-dashboard-csrf"]
    verbs          = ["get", "update", "delete"]
  }
  rule {
    # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["kubernetes-dashboard-settings"]
    verbs          = ["get", "update"]
  }
  rule {
    # Allow Dashboard to get metrics.
    api_groups     = [""]
    resources      = ["services"]
    resource_names = ["heapster", "dashboard-metrics-scraper"]
    verbs          = ["proxy"]
  }
  rule {
    api_groups     = [""]
    resources      = ["services/proxy"]
    resource_names = ["heapster", "http:heapster:", "https:heapster:", "dashboard-metrics-scraper", "http:dashboard-metrics-scraper"]
    verbs          = ["get"]
  }
}


resource "kubernetes_cluster_role" "kube_dashboard" {
  depends_on = [kubernetes_namespace.kube_dashboard]
  metadata {
    name = "kubernetes-dashboard"
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  rule {
    # Allow Metrics Scraper to get metrics from the Metrics server
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "kube_dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.kube_dashboard.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kube_dashboard.metadata.0.name
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
  }
}

resource "kubernetes_cluster_role_binding" "kube_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kube_dashboard.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kube_dashboard.metadata.0.name
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
  }
}

resource "kubernetes_deployment" "kube_dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  spec {
    replicas               = 1
    revision_history_limit = 10
    selector {
      match_labels = {
        "k8s-app" = "kubernetes-dashboard"
      }
    }
    template {
      metadata {
        labels = {
          "k8s-app" = "kubernetes-dashboard"
        }
      }
      spec {
        container {
          name              = "kubernetes-dashboard"
          image             = "kubernetesui/dashboard:v${var.dashboard_version}"
          image_pull_policy = "Always"
          port {
            container_port = 8443
            protocol       = "TCP"
          }
          args = [
            "--auto-generate-certificates",
            "--namespace=kubernetes-dashboard",
            # Uncomment the following line to manually specify Kubernetes API server Host
            # If not specified, Dashboard will attempt to auto discover the API server and connect
            # to it. Uncomment only if the default does not work.
            # "--apiserver-host=http://my-address:port"
          ]
          volume_mount {
            name       = "kubernetes-dashboard-certs"
            mount_path = "/certs"
          }
          volume_mount {
            # Create on-disk volume to store exec logs
            mount_path = "/tmp"
            name       = "tmp-volume"
          }
          liveness_probe {
            http_get {
              scheme = "HTTPS"
              path   = "/"
              port   = 8443
            }
            initial_delay_seconds = 30
            timeout_seconds       = 30
          }
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 1001
            run_as_group               = 2001
          }
        }
        volume {
          name = "kubernetes-dashboard-certs"
          secret {
            secret_name = "kubernetes-dashboard-certs"
          }
        }
        volume {
          name = "tmp-volume"
          empty_dir {
          }
        }
        service_account_name            = "kubernetes-dashboard"
        automount_service_account_token = true
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
        toleration {
          # Comment the following tolerations if Dashboard must not be deployed on master
          key    = "node-role.kubernetes.io/master"
          effect = "NoSchedule"
        }
      }
    }
  }
}

resource "kubernetes_service" "kube_dashboard_scraper" {
  metadata {
    name      = "dashboard-metrics-scraper"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  spec {
    port {
      port        = 8000
      target_port = 8000
    }
    selector = {
      "k8s-app" = "dashboard-metrics-scraper"
    }
  }
}

resource "kubernetes_deployment" "kube_dashboard_scraper" {
  metadata {
    name      = "dashboard-metrics-scraper"
    namespace = kubernetes_namespace.kube_dashboard.metadata.0.name
    labels = {
      "k8s-app" = "kubernetes-dashboard"
    }
  }
  spec {
    replicas               = 1
    revision_history_limit = 10
    selector {
      match_labels = {
        "k8s-app" = "dashboard-metrics-scraper"
      }
    }
    template {
      metadata {
        labels = {
          "k8s-app" = "dashboard-metrics-scraper"
        }
        annotations = {
          "seccomp.security.alpha.kubernetes.io/pod" = "runtime/default"
        }
      }
      spec {
        container {
          name  = "dashboard-metrics-scraper"
          image = "kubernetesui/metrics-scraper:v${var.metrics_scraper_version}"
          port {
            container_port = 8000
            protocol       = "TCP"
          }
          liveness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/"
              port   = 8000
            }
            initial_delay_seconds = 30
            timeout_seconds       = 30
          }
          volume_mount {
            mount_path = "/tmp"
            name       = "tmp-volume"
          }
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 1001
            run_as_group               = 2001
          }
        }
        service_account_name            = kubernetes_service_account.kube_dashboard.metadata.0.name
        automount_service_account_token = true
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
        toleration {
          # Comment the following tolerations if Dashboard must not be deployed on master
          key    = "node-role.kubernetes.io/master"
          effect = "NoSchedule"
        }
        volume {
          name = "tmp-volume"
          empty_dir {}
        }
      }
    }
  }
}