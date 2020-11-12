locals {
  namespace = kubernetes_namespace.cvmfs
}

resource "kubernetes_namespace" "cvmfs" {
  metadata {
    name = "cvmfs"
  }
}

resource "kubernetes_config_map" "csi_config" {
  metadata {
    generate_name = "cvmfs-csi-config-"
    namespace     = local.namespace.metadata.0.name
  }
  data = {
    "config.json" = <<-EOF
    []
    EOF
  }
}

resource "kubernetes_config_map" "config" {
  metadata {
    generate_name = "cvmfs-csi-config-"
    namespace     = local.namespace.metadata.0.name
  }
  data = {
    "default.local" = <<-EOF
    EOF
  }
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