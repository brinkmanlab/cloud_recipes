/*
The external-attacher is a sidecar container that attaches volumes to nodes by calling ControllerPublish and
ControllerUnpublish functions of CSI drivers. It is necessary because internal Attach/Detach controller running
in Kubernetes controller-manager does not have any direct interfaces to CSI drivers.

In Kubernetes, the term attach means 3rd party volume attachment to a node. This is common in cloud environments,
where the cloud API is able to attach a volume to a node without any code running on the node. In CSI terminology,
this corresponds to the ControllerPublish call.

Detach is the reverse operation, 3rd party volume detachment from a node, ControllerUnpublish in CSI terminology.

It is not an attach/detach operation performed by a code running on a node, such as an attachment of iSCSI or Fibre
Channel volumes. These are typically performed during NodeStage and NodeUnstage CSI calls and are not done by the
external-attacher.

The external-attacher is an external controller that monitors VolumeAttachment objects created by controller-manager
and attaches/detaches volumes to/from nodes (i.e. calls ControllerPublish/ControllerUnpublish.

See https://github.com/kubernetes-csi/external-attacher
*/

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
    name = "cvmfs-attacher-role"
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
      match_labels = {
        App = "csi-cvmfsplugin-attacher"
      }
    }
    update_strategy {
      type = "RollingUpdate"
    }
    template {
      metadata {
        labels = {
          App = "csi-cvmfsplugin-attacher"
        }
      }
      spec {
        service_account_name            = kubernetes_service_account.attacher.metadata.0.name
        automount_service_account_token = true
        container {
          name              = "csi-attacher"
          image             = "quay.io/k8scsi/csi-attacher:${var.csi_attacher_tag}"
          image_pull_policy = "IfNotPresent"
          args              = ["--v=5", "--csi-address=$(ADDRESS)"]
          env {
            name  = "ADDRESS"
            value = "${local.plugin_dir}/csi.sock"
          }
          volume_mount {
            mount_path = local.plugin_dir
            name       = "plugin-dir"
          }
        }
        node_selector = {
          WorkClass = "service"
        }
        volume {
          name = "plugin-dir"
          host_path {
            path = local.plugin_dir
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}