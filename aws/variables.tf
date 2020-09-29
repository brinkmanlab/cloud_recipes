locals {
  cluster_name = "${var.cluster_name}${local.name_suffix}"
  instance     = var.instance == "" ? "default" : var.instance
  name_suffix  = var.instance == "" ? "" : "-${var.instance}"
}

variable "cluster_name" {
  type = string
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