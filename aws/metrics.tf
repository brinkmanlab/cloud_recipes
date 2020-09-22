resource "kubernetes_cluster_role" "aggregated_metrics_reader" {
  metadata {
    name = "system:aggregated-metrics-reader"
    labels = {
      "rbac.authorization.k8s.io/aggregate-to-view"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
    }
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "auth_delegator" {
  metadata {
    name = "metrics-server:system:auth-delegator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_role_binding" "auth_reader" {
  metadata {
    name      = "metrics-server-auth-reader"
    namespace = "kube-system"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "extension-apiserver-authentication-reader"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_api_service" "metrics" {
  metadata {
    name = "v1beta1.metrics.k8s.io"
  }
  spec {
    service {
      name      = "metrics-server"
      namespace = "kube-system"
    }
    group                    = "metrics.k8s.io"
    version                  = "v1beta1"
    insecure_skip_tls_verify = true
    group_priority_minimum   = 100
    version_priority         = 100
  }
}

resource "kubernetes_service_account" "metrics" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_deployment" "metrics" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      k8s-app = "metrics-server"
    }
  }
  spec {
    selector {
      match_labels = {
        k8s-app = "metrics-server"
      }
    }
    template {
      metadata {
        name = "metrics-server"
        labels = {
          k8s-app = "metrics-server"
        }
      }
      spec {
        service_account_name            = "metrics-server"
        automount_service_account_token = true
        volume {
          name = "tmp-dir"
          empty_dir {}
        }
        container {
          name              = "metrics-server"
          image             = "k8s.gcr.io/metrics-server-amd64:v0.3.6"
          image_pull_policy = "IfNotPresent"
          args = [
            "--v=2",
            "--cert-dir=/tmp",
            "--secure-port=4443",
            "--kubelet-preferred-address-types=InternalIP",
            "--kubelet-insecure-tls",
          ]

          port {
            name           = "main-port"
            container_port = 4443
            protocol       = "TCP"
          }

          security_context {
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "tmp-dir"
          }
        }
        node_selector = {
          "kubernetes.io/os"   = "linux"
          "kubernetes.io/arch" = "amd64"
        }
      }
    }
  }
}

resource "kubernetes_service" "metrics" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      "kubernetes.io/name"            = "Metrics-server"
      "kubernetes.io/cluster-service" = "true"
    }
  }
  spec {
    selector = {
      "k8s-app" = "metrics-server"
    }
    port {
      port        = 443
      protocol    = "TCP"
      target_port = "main-port"
    }
  }
}

resource "kubernetes_cluster_role" "metrics" {
  metadata {
    name = "system:metrics-server"
  }
  rule {
    api_groups = [""]
    resources = [
      "pods",
      "nodes",
      "nodes/stats",
      "namespaces",
      "configmaps",
    ]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "metrics" {
  metadata {
    name = "system:metrics-server"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:metrics-server"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "metrics-server"
    namespace = "kube-system"
  }
}