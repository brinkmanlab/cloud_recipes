locals {
  namespace         = kubernetes_namespace.cvmfs
  CVMFS_KEYS_DIR    = "/etc/cvmfs/keys/"
  CVMFS_CACHE_BASE  = "/mnt/cvmfs/localcache"
  CVMFS_ALIEN_CACHE = "/mnt/cvmfs/aliencache"
  plugin_dir        = "/var/lib/kubelet/plugins/csi-cvmfsplugin"
}

resource "kubernetes_namespace" "cvmfs" {
  metadata {
    name = "cvmfs"
  }
}

resource "kubernetes_config_map" "config" {
  metadata {
    generate_name = "cvmfs-csi-config-"
    namespace     = local.namespace.metadata.0.name
  }
  data = { #TODO set up s3fs to host alien cache
    "default.local" = <<-EOF
      CVMFS_SERVER_URL="${join(";", var.servers)}"
      CVMFS_KEYS_DIR="${local.CVMFS_KEYS_DIR}"
      CVMFS_USE_GEOAPI=yes
      CVMFS_HTTP_PROXY="DIRECT"
      CVMFS_CACHE_BASE="${local.CVMFS_CACHE_BASE}"
      # CVMFS_ALIEN_CACHE="${local.CVMFS_ALIEN_CACHE}"
      # When alien cache is used, CVMFS does not control the size of the cache
      CVMFS_QUOTA_LIMIT=-1
      # For clarification, this is referencing whether repositories
      # should share a cache directory or each have their own
      CVMFS_SHARED_CACHE=no
    EOF
  }
}

resource "kubernetes_config_map" "repo_keys" {
  metadata {
    generate_name = "cvmfs-repo-keys-"
    namespace     = local.namespace.metadata.0.name
  }
  data = { for i, key in var.cvmfs_keys : "repo_key${i}.pub" => key }
}

resource "kubernetes_csi_driver" "plugin" {
  metadata {
    name      = "csi-cvmfsplugin"
    namespace = local.namespace.metadata.0.name
  }
  spec {
    attach_required   = true
    pod_info_on_mount = true
  }
}

/*
resource "kubernetes_cluster_role_binding" "psp" {
  metadata {
    name = "cvmfs-psp"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "psp:privileged-user"
  }
  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.nodeplugin.metadata.0.name
    namespace = kubernetes_namespace.cvmfs.metadata.0.name
  }
  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.attacher.metadata.0.name
    namespace = kubernetes_namespace.cvmfs.metadata.0.name
  }
  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account.provisioner.metadata.0.name
    namespace = kubernetes_namespace.cvmfs.metadata.0.name
  }
}
*/