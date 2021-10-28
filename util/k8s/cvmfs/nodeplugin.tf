/*
The node-driver-registrar is a sidecar container that registers the CSI driver with Kubelet using the kubelet plugin
registration mechanism.

This is necessary because Kubelet is responsible for issuing CSI NodeGetInfo, NodeStageVolume, NodePublishVolume calls.
The node-driver-registrar registers your CSI driver with Kubelet so that it knows which Unix domain socket to issue the CSI calls on.

See https://github.com/kubernetes-csi/node-driver-registrar
*/

locals {
  liveness_probe = ["bash", "-c", "! cvmfs_config probe | grep -v OK"] # TODO factor out into variable when refactoring entire module into two, CSI and CVMFS
}

resource "kubernetes_service_account" "nodeplugin" {
  metadata {
    name      = "cvmfs-csi-nodeplugin"
    namespace = local.namespace.metadata.0.name
  }
}

resource "kubernetes_cluster_role" "nodeplugin" {
  metadata {
    name = "cvmfs-csi-nodeplugin-rules"
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
    name      = kubernetes_cluster_role.nodeplugin.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_daemonset" "plugin" {
  depends_on = [kubernetes_cluster_role_binding.nodeplugin]
  metadata {
    name      = "csi-cvmfsplugin"
    namespace = local.namespace.metadata.0.name
  }
  spec {
    selector {
      match_labels = {
        App = "csi-cvmfsplugin"
      }
    }
    template {
      metadata {
        labels = {
          App = "csi-cvmfsplugin"
        }
      }
      spec {
        service_account_name            = kubernetes_service_account.nodeplugin.metadata.0.name
        automount_service_account_token = true
        host_network                    = true
        container {
          name  = "driver-registrar"
          image = "quay.io/k8scsi/csi-node-driver-registrar:${var.csi_node_driver_tag}"
          args = [
            "--v=5",
            "--csi-address=/csi/csi.sock",
            "--kubelet-registration-path=${local.plugin_dir}/csi.sock",
          ]
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "rm -rf /registration/${local.driver_name} /registration/${local.driver_name}-reg.sock"]
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
            name       = "plugin-dir"
          }
          volume_mount {
            mount_path = "/registration"
            name       = "registration-dir"
          }
        }
        container {
          name              = "csi-cvmfsplugin"
          image             = "${var.cvmfs_csi_driver}:${var.cvmfs_csi_tag}"
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
            "--endpoint=unix://csi/csi.sock",
            "--v=5",
            "--drivername=${local.driver_name}",
            #"--metadatastorage=k8s_configmap",
            #"--mountcachedir=/mount-cache-dir",
          ]
          env {
            name = "NODE_ID"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          dynamic "liveness_probe" {
            for_each = local.liveness_probe == null ? [] : [local.liveness_probe]
            content {
              exec {
                command = liveness_probe.value
              }
              initial_delay_seconds = 30
              period_seconds        = 30
              timeout_seconds       = 60
            }
          }
          volume_mount {
            mount_path = "/csi"
            name       = "plugin-dir"
          }
          volume_mount {
            mount_path        = "/var/lib/kubelet/pods"
            name              = "pods-mount-dir"
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
            mount_path = local.CVMFS_KEYS_DIR
            name       = "cvmfs-keys"
          }
          volume_mount {
            mount_path = "/etc/cvmfs/default.local"
            name       = "cvmfs-config"
            sub_path   = "default.local"
          }
          volume_mount {
            mount_path = local.CVMFS_CACHE_BASE
            name       = "cvmfs-local-cache"
          }

          # TODO volume_mount {
          #   mount_path = local.CVMFS_ALIEN_CACHE
          #   name       = "cvmfs-alien-cache"
          # }
        }
        volume {
          name = "cvmfs-local-cache"
          empty_dir {}
        }
        volume {
          name = "registration-dir"
          host_path {
            path = "/var/lib/kubelet/plugins_registry/"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "pods-mount-dir"
          host_path {
            path = "/var/lib/kubelet/pods"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "plugin-dir"
          host_path {
            path = local.plugin_dir
            type = "DirectoryOrCreate"
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