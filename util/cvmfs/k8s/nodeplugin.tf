resource "kubernetes_service_account" "nodeplugin" {
  metadata {
    name      = "cvmfs-csi-nodeplugin"
    namespace = local.namespace.metadata.0.name
  }
}

resource "kubernetes_cluster_role" "nodeplugin_aggregate" {
  metadata {
    name = "cvmfs-csi-nodeplugin"
  }
  aggregation_rule {
    cluster_role_selectors {
      match_labels = {
        "rbac.cvmfs.csi.cern.ch/aggregate-to-cvmfs-csi-nodeplugin" = true
      }
    }
  }
}

resource "kubernetes_cluster_role" "nodeplugin" {
  metadata {
    name = "cvmfs-csi-nodeplugin-rules"
    labels = {
      "rbac.cvmfs.csi.cern.ch/aggregate-to-cvmfs-csi-nodeplugin" = true
    }
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = ["get", "list", "watch", "update"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = ["get", "list", "watch", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "nodeplugin" {
  metadata {
    name = "cvmfs-csi-nodeplugin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nodeplugin.metadata.0.name
    namespace = local.namespace.metadata.0.name
  }
  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.nodeplugin_aggregate.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_daemonset" "plugin" {
  metadata {
    name      = "csi-cvmfsplugin"
    namespace = kubernetes_namespace.cvmfs.metadata.0.name
  }
  spec {
    selector {
      App = "csi-cvmfsplugin"
    }
    template {
      metadata {
        labels = {
          App = "csi-cvmfsplugin"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.nodeplugin.metadata.0.name
        host_network         = true
        container {
          name  = "driver-registrar"
          image = "quay.io/k8scsi/csi-node-driver-registrar:${var.csi_node_driver_tag}"
          args = [
            "--v=5",
            "--csi-address=/csi/csi.sock",
            "--kubelet-registration-path=/var/lib/kubelet/plugins/cvmfs.csi.cern.ch/csi.sock",
          ]
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "rm -rf /registration/csi-cvmfsplugin /registration/csi-cvmfsplugin-reg.sock"]
              }
            }
          }
          env {
            name = "KUBE_NODE_NAME"
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
            mount_path = "/registration"
            name       = "registration-dir"
          }
        }
        container {
          name              = "csi-cvmfsplugin"
          image             = "computecanada/csi-cvmfsplugin:${var.cvmfs_csi_tag}"
          image_pull_policy = "IfNotPresent"
          security_context {
            privileged = true
            capabilities {
              add = ["SYS_ADMIN"]
            }
            allow_privilege_escalation = true
          }
          args = [
            "--nodeid=$(NODE_ID)",
            "--type=cvmfs",
            "--nodeserver=true",
            "--endpoint=$(CSI_ENDPOINT)",
            "--v=5",
            "--drivername=cvmfs.csi.cern.ch",
            "--metadatastorage=k8s_configmap",
            "--mountcachedir=/mount-cache-dir",
          ]
          env {
            name = "NODE_ID"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name  = "CSI_ENDPOINT"
            value = "unix:///csi/csi-provisioner.sock"
          }
          volume_mount {
            mount_path = "/mount-cache-dir"
            name       = "mount-cache-dir"
          }
          volume_mount {
            mount_path = "/csi"
            name       = "socket-dir"
          }
          volume_mount {
            mount_path        = "/var/lib/kubelet/pods"
            name              = "mountpoint-dir"
            mount_propagation = "Bidirectional"
          }
          volume_mount {
            mount_path        = "/var/lib/kubelet/plugins"
            name              = "plugin-dir"
            mount_propagation = "Bidirectional"
          }
          volume_mount {
            mount_path = "/sys"
            name       = "host-sys"
          }
          volume_mount {
            mount_path = "/lib/modules"
            name       = "lib-modules"
            read_only  = true
          }
          volume_mount {
            mount_path = "/dev"
            name       = "host-dev"
          }
          volume_mount {
            mount_path = "/etc/cvmfs-csi-config/"
            name       = "cvmfs-csi-config"
          }
          volume_mount {
            mount_path = "/tmp/csi/keys"
            name       = "keys-tmp-dir"
          }
          volume_mount {
            mount_path = "/etc/cvmfs/default.local"
            name       = "cvmfs-config"
            sub_path   = "cvmfs-override"
          }
        }
        volume {
          name = "mount-cache-dir"
          empty_dir {}
        }
        volume {
          name = "socket-dir"
          host_path {
            path = "/var/lib/kubelet/plugins/cvmfs.csi.cern.ch/"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "registration-dir"
          host_path {
            path = "/var/lib/kubelet/plugins_registry/"
            type = "Directory"
          }
        }
        volume {
          name = "mountpoint-dir"
          host_path {
            path = "/var/lib/kubelet/pods"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "plugin-dir"
          host_path {
            path = "/var/lib/kubelet/plugins"
            type = "Directory"
          }
        }
        volume {
          name = "host-sys"
          host_path {
            path = "/sys"
          }
        }
        volume {
          name = "lib-modules"
          host_path {
            path = "/lib/modules"
          }
        }
        volume {
          name = "host-dev"
          host_path {
            path = "/dev"
          }
        }
        volume {
          name = "cvmfs-csi-config"
          config_map {
            name = kubernetes_config_map.csi_config.metadata.0.name
          }
        }
        volume {
          name = "keys-tmp-dir"
          empty_dir {
            medium = "Memory"
          }
        }
        volume {
          name = "cvmfs-config"
          config_map {
            name = kubernetes_config_map.config.metadata.0.name
          }
        }
      }
    }
  }
}