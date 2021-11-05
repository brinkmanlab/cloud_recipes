/*
The external-provisioner is a sidecar container that dynamically provisions volumes by calling ControllerCreateVolume
and ControllerDeleteVolume functions of CSI drivers. It is necessary because internal persistent volume controller
running in Kubernetes controller-manager does not have any direct interfaces to CSI drivers.

The external-provisioner is an external controller that monitors PersistentVolumeClaim objects created by user and
creates/deletes volumes for them.

See https://github.com/kubernetes-csi/external-provisioner
*/

resource "kubernetes_service_account" "provisioner" {
  metadata {
    name      = "cvmfs-provisioner"
    namespace = local.namespace.metadata.0.name
  }
}

resource "kubernetes_cluster_role" "provisioner" {
  metadata {
    name = "cvmfs-external-provisioner-runner"
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["list", "watch", "create", "update", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "update"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["csi.storage.k8s.io"]
    resources  = ["csinodeinfos"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = ["get", "list", "watch", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "provisioner" {
  metadata {
    name = "cvmfs-csi-provisioner-role"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.provisioner.metadata.0.name
    namespace = local.namespace.metadata.0.name
  }
  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.provisioner.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role" "cvmfs_provisioner" {
  metadata {
    name      = "cvmfs-external-provisioner-cfg"
    namespace = local.namespace.metadata.0.name
  }
  rule {
    api_groups = [""]
    resources  = ["endpoints"]
    verbs      = ["get", "watch", "list", "delete", "update", "create"]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "create", "delete"]
  }
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "watch", "list", "delete", "update", "create"]
  }
}

resource "kubernetes_role_binding" "provisioner" {
  metadata {
    name      = "cvmfs-csi-provisioner-role-cfg"
    namespace = local.namespace.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cvmfs_provisioner.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.provisioner.metadata.0.name
    namespace = local.namespace.metadata.0.name
  }
}

resource "kubernetes_service" "provisioner" {
  metadata {
    generate_name = "csi-cvmfsplugin-provisioner-"
    namespace     = local.namespace.metadata.0.name
  }
  spec {
    selector = {
      App = "csi-cvmfsplugin-provisioner"
    }
    port {
      port = 8080
    }
    cluster_ip = "None"
    type       = "ClusterIP"
  }
}

resource "kubernetes_stateful_set" "provisioner" {
  depends_on = [kubernetes_cluster_role_binding.provisioner, kubernetes_role_binding.provisioner]
  metadata {
    generate_name = "csi-cvmfsplugin-provisioner-"
    namespace     = local.namespace.metadata.0.name
  }
  spec {
    replicas               = 1
    revision_history_limit = 1
    service_name           = kubernetes_service.provisioner.metadata.0.name
    selector {
      match_labels = {
        App = "csi-cvmfsplugin-provisioner"
      }
    }
    template {
      metadata {
        labels = {
          App = "csi-cvmfsplugin-provisioner"
        }
      }
      spec {
        service_account_name            = kubernetes_service_account.provisioner.metadata.0.name
        automount_service_account_token = true
        container {
          name              = "csi-provisioner"
          image             = "quay.io/k8scsi/csi-provisioner:${var.csi_provisioner_tag}"
          image_pull_policy = "IfNotPresent"
          args = [
            "--csi-address=/csi/csi.sock",
            "--v=5",
            "--http-endpoint=:8080",
          ]
          liveness_probe {
            http_get {
              scheme = "HTTP"
              path   = "/healthz"
              port   = 8080
            }
          }
          volume_mount {
            mount_path = "/csi"
            name       = "socket-dir"
          }
        }
        container {
          name              = "csi-cvmfsplugin"
          image             = "${var.cvmfs_csi_driver}:${var.cvmfs_csi_tag}"
          image_pull_policy = "IfNotPresent"
          args = [
            "--nodeid=$(NODE_ID)",
            "--endpoint=unix://csi/csi.sock",
            "--v=5",
            "--drivername=${local.driver_name}",
          ]
          env {
            name = "NODE_ID"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          volume_mount {
            mount_path = "/csi"
            name       = "socket-dir"
          }
          volume_mount {
            mount_path = local.CVMFS_KEYS_DIR
            name       = "cvmfs-keys"
          }
          volume_mount {
            mount_path = "/etc/cvmfs/default.local"
            name       = "cvmfs-config"
            sub_path   = "default.local"
          }
        }
        node_selector = {
          WorkClass = "service"
        }
        volume {
          name = "socket-dir"
          empty_dir {}
        }
        volume {
          name = "cvmfs-config"
          config_map {
            name = kubernetes_config_map.config.metadata.0.name
          }
        }
        volume {
          name = "cvmfs-keys"
          config_map {
            name = kubernetes_config_map.repo_keys.metadata.0.name
          }
        }
      }
    }
  }
}