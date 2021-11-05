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

variable "csi_node_driver_tag" {
  type    = string
  default = "v2.0.1"
}

variable "cvmfs_csi_tag" {
  type    = string
  default = "1.2.0"
}

variable "cvmfs_csi_driver" {
  type    = string
  default = "brinkmanlab/csi-cvmfsplugin"
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

variable "stratum0s" {
  type        = set(string)
  default     = []
  description = "Set of stratum-0 servers to fetch stratum-1 server lists from for CVMFS_SERVER_URL"
}

variable "servers" {
  type        = set(string)
  default     = []
  description = "Set of servers as provided to CVMFS_SERVER_URL"
}

variable "extra_config" {
  type        = map(string)
  default     = {}
  description = "Extra CVMFS Key-values to include in default local"
}