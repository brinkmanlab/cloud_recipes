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

resource "kubernetes_cluster_role" "provisioner_aggregate" {
  metadata {
    name = "cvmfs-external-provisioner-runner-aggregate"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_labels = {
        "rbac.cvmfs.csi.cern.ch/aggregate-to-cvmfs-external-provisioner-runner" = true
      }
    }
  }
}

resource "kubernetes_cluster_role" "provisioner" {
  metadata {
    name = "cvmfs-external-provisioner-runner"
    labels = {
      "rbac.cvmfs.csi.cern.ch/aggregate-to-cvmfs-external-provisioner-runner" = true
    }
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
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
    name      = kubernetes_cluster_role.provisioner_aggregate.metadata.0.name
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
    labels = {
      App = "csi-cvmfsplugin-provisioner"
    }
  }
  spec {
    selector = {
      App = "csi-cvmfsplugin-provisioner"
    }
    port {
      name = "dummy"
      port = 12345
    }
  }
}

resource "kubernetes_stateful_set" "provisioner" {
  metadata {
    generate_name = "csi-cvmfsplugin-provisioner-"
    namespace     = local.namespace.metadata.0.name
  }
  spec {
    service_name = "csi-cvmfsplugin-provisioner"
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
        service_account_name = kubernetes_service_account.provisioner.metadata.0.name
        container {
          name              = "csi-provisioner"
          image             = "quay.io/k8scsi/csi-provisioner:${var.csi_provisioner_tag}"
          image_pull_policy = "IfNotPresent"
          args = [
            "--csi-address=$(ADDRESS)",
            "--v=5",
            "--timeout=60s",
            "--enable-leader-election=true",
            "--leader-election-type=leases",
            "--retry-interval-start=500ms",
          ]
          env {
            name  = "ADDRESS"
            value = "unix:///csi/csi-provisioner.sock"
          }
          volume_mount {
            mount_path = "/csi"
            name       = "socket-dir"
          }
        }
        container {
          name              = "csi-cvmfsplugin-attacher"
          image             = "quay.io/k8scsi/csi-attacher:${var.csi_attacher_tag}"
          image_pull_policy = "IfNotPresent"
          args = [
            "--v=5",
            "--csi-address=$(ADDRESS)",
            "--provisioner=csi-cvmfsplugin",
          ]
          env {
            name  = "ADDRESS"
            value = "/csi/csi-provisioner.sock"
          }
          volume_mount {
            mount_path = "/csi"
            name       = "socket-dir"
          }
        }
        volume {
          name = "socket-dir"
          host_path {
            path = "/var/lib/kubelet/plugins/cvmfs.csi.cern.ch"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}