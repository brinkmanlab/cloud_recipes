locals {
  namespace           = var.namespace != null ? var.namespace : kubernetes_namespace.cvmfs[0]
  CVMFS_KEYS_DIR      = "/etc/cvmfs/keys/"
  CVMFS_CACHE_BASE    = "/var/cache/cvmfs"
  CVMFS_ALIEN_CACHE   = "/mnt/cvmfs/aliencache"
  plugin_dir          = "/var/lib/kubelet/plugins/${local.driver_name}"
  driver_name         = "cvmfsdriver"
  recommended_servers = compact(flatten([for v in values(data.http.stratum0_info)[*].body : try(jsondecode(v)["recommended-stratum1s"], [])]))
  servers             = toset(concat(tolist(var.servers), local.recommended_servers))
  extra_config        = join("\n", [for k, v in var.extra_config : "${k}=${v}"])
}

data "http" "stratum0_info" {
  for_each = var.stratum0s
  url      = "http://${each.value}/cvmfs/info/v1/meta.json"

  request_headers = {
    Accept = "application/json"
  }
}

resource "kubernetes_namespace" "cvmfs" {
  count = var.namespace == null ? 1 : 0
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
      CVMFS_SERVER_URL="${join(";", local.servers)}"
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
      CVMFS_CHECK_PERMISSIONS=no
      ${local.extra_config}
    EOF
  }
}

resource "kubernetes_config_map" "repo_keys" {
  metadata {
    generate_name = "cvmfs-repo-keys-"
    namespace     = local.namespace.metadata.0.name
  }
  data = { for repo, key in var.cvmfs_keys : "${repo}.pub" => key }
}

// https://kubernetes-csi.github.io/docs/csi-driver-object.html
resource "kubernetes_csi_driver" "driver" {
  metadata {
    name = local.driver_name
  }
  spec {
    attach_required        = false
    pod_info_on_mount      = false
    volume_lifecycle_modes = ["Persistent"]
  }
}

resource "kubernetes_storage_class" "repos" {
  depends_on             = [kubernetes_daemonset.plugin, kubernetes_stateful_set.provisioner, kubernetes_deployment.attacher]
  for_each               = var.cvmfs_repos
  storage_provisioner    = local.driver_name
  allow_volume_expansion = false
  metadata {
    name = "cvmfs-${each.key}"
  }
  parameters = merge({
    repository = each.value.repo
  }, each.value.tag != "" ? { tag = each.value.tag } : {})
}