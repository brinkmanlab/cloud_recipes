locals {
  cluster_name = "${var.cluster_name}${local.name_suffix}"
  instance     = var.instance == "" ? "default" : var.instance
  name_suffix  = var.instance == "" ? "" : "-${var.instance}"
}

variable "cluster_name" {
  type = string
}

variable "instance" {
  type = string
  default = ""
}

variable "debug" {
  type = bool
  default = false
}