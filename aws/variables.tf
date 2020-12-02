locals {
  cluster_name = "${var.cluster_name}${local.name_suffix}"
  instance     = var.instance == "" ? "default" : var.instance
  name_suffix  = var.instance == "" ? "" : "-${var.instance}"
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type        = string
  default     = "1.18"
  description = "Kubernetes cluster version"
}

variable "instance" {
  type    = string
  default = ""
}

variable "debug" {
  type    = bool
  default = false
}

variable "dashboard_version" {
  type    = string
  default = "2.0.0"
}

variable "metrics_scraper_version" {
  type    = string
  default = "1.0.4"
}

variable "metrics_server_version" {
  type    = string
  default = "0.3.6"
}

variable "autoscaler_version" {
  type    = string
  default = "1.19.0" # https://console.cloud.google.com/gcr/images/google-containers/GLOBAL/cluster-autoscaler?gcrImageListsize=30
}

variable "docker_registry_proxies" {
  type = map(object({
    hostname = string
    url      = string
    username = string
    password = string
  }))
  default     = {}
  description = "Docker registries to proxy"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap. See examples/basic/variables.tf for example format."
  type        = list(string)
  default     = []
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap. See examples/basic/variables.tf for example format."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap. See examples/basic/variables.tf for example format."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
