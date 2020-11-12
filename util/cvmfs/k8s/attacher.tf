resource "kubernetes_service_account" "attacher" {
  metadata {
    name      = "cvmfs-attacher"
    namespace = local.namespace.metadata.0.name
  }
}

resource "kubernetes_cluster_role" "attacher" {
  metadata {
    name = "cvmfs-external-attacher-runner"
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = ["get", "list", "watch", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = ["get", "list", "watch", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "attacher" {
  metadata {
    name      = "cvmfs-attacher-role"
    namespace = local.namespace.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.attacher.metadata.0.name
    namespace = local.namespace.metadata.0.name
  }
  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.attacher.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_service" "attacher" {
  metadata {
    generate_name = "csi-cvmfsplugin-attacher-"
    namespace     = local.namespace.metadata.0.name
    labels = {
      App = "csi-cvmfsplugin-attacher"
    }
  }
  spec {
    selector = {
      App = "csi-cvmfsplugin-attacher"
    }
    port {
      name = "dummy"
      port = 12345
    }
  }
}

resource "kubernetes_stateful_set" "attacher" {
  metadata {
    generate_name = "csi-cvmfsplugin-attacher-"
    namespace     = local.namespace.metadata.0.name
  }
  spec {
    service_name = kubernetes_service.attacher.metadata.0.name
    replicas     = 1
    selector {
      App = "csi-cvmfsplugin-attacher"
    }
    template {
      metadata {
        labels = {
          App = "csi-cvmfsplugin-attacher"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.attacher.metadata.0.name
        container {
          name              = "csi-attacher"
          image             = "quay.io/k8scsi/csi-attacher:${var.csi_attacher_tag}"
          image_pull_policy = "IfNotPresent"
          args              = ["--v=5", "--csi-address=$(ADDRESS)"]
          env {
            name  = "ADDRESS"
            value = "/var/lib/kubelet/plugins/csi-cvmfsplugin/csi.sock"
          }
          volume_mount {
            mount_path = "/var/lib/kubelet/plugins/csi-cvmfsplugin"
            name       = "socket-dir"
          }
        }
        volume {
          name = "socket-dir"
          host_path {
            path = "/var/lib/kubelet/plugins/csi-cvmfsplugin"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}