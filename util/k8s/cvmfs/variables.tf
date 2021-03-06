variable "namespace" {
  default     = null
  description = "Instance of kubernetes_namespace to provision instance resources under"
}

variable "csi_attacher_tag" {
  type    = string
  default = "v3.0.0"
}

variable "csi_provisioner_tag" {
  type    = string
  default = "v2.0.2"
}

variable "cvmfs_csi_tag" {
  type    = string
  default = "v1.0.1"
}

variable "csi_node_driver_tag" {
  type    = string
  default = "v2.0.1"
}

variable "cvmfs_keys" {
  type        = map(string)
  description = "CVMFS Repository public keys keyed on repo name"
}

variable "cvmfs_repo_tags" {
  type        = map(string)
  default     = {}
  description = "CVMFS Repository commit tag to mount, keyed on repo name. Defaults to 'trunk'."
}

variable "servers" {
  type        = set(string)
  description = "Set of servers as provided to CVMFS_SERVER_URL"
}