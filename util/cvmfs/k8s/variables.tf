variable "namespace" {
  description = "Instance of kubernetes_namespace to provision instance resources under"
}

variable "csi_attacher_tag" {
  type    = string
  default = "v2.1.1"
}

variable "csi_provisioner_tag" {
  type    = string
  default = "v1.5.0"
}

variable "cvmfs_csi_tag" {
  type    = string
  default = "latest"
}

variable "csi_node_driver_tag" {
  type    = string
  default = "v1.2.0"
}