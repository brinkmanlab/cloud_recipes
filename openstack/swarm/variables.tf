variable "sec_groups" {
  type        = list(string)
  default     = []
  description = "List of security group ids to attach to engine nodes"
}

variable "manager1_flavor" {
  type        = string
  default     = "p8-12gb"
  description = "Flavor of VM to allocate for manager1. Should be a persistent node."
}

variable "manager_replicates" {
  type        = number
  default     = 2
  description = "Number of manager replicates"
}

variable "worker_replicates" {
  type        = number
  default     = 2
  description = "Number of manager replicates"
}

variable "manager_flavor" {
  type        = string
  default     = "c4-15gb-83"
  description = "Flavor of VM to allocate for redundant managers"
}

variable "worker_flavor" {
  type        = string
  default     = "c8-30gb-186"
  description = "Flavor of VM to allocate for workers"
}

variable "image_url" {
  type        = string
  default     = null
  description = "URL of image to base VMs on"
}

variable "image_name" {
  type        = string
  default     = null
  description = "Name of pre-existing image to use for swarm nodes"
}

variable "key_pair" {
  type        = string
  description = "Name of key pair to load into VMs"
}

variable "private_key" {
  type        = string
  description = "Private key contents of key_pair"
}

#variable "key_cert" {
#  type        = string
#  description = "CA certificate used to sign private_key"
#}

variable "vm_user" {
  type        = string
  description = "User name associated with private key"
}

variable "init-cmds" {
  type        = list(string)
  default     = []
  description = "list of shell commands to run on each node during init"
}

variable "configs" {
  type        = object({ path : string, content : string })
  default     = {}
  description = "map of paths to content to write to node before init"
}