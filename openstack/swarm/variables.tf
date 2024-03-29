variable "sec_groups" {
  type        = list(string)
  default     = []
  description = "List of security group ids to attach to engine nodes"
}

variable "public_network" {
  type        = string
  default     = "Public-Network"
  description = "Name of public network to register manager1 fip"
}

variable "private_network" {
  type        = string
  description = "Name of private network to register nodes on"
}

variable "manager1_flavor" {
  type        = string
  description = "Flavor of VM to allocate for manager1. Should be a persistent node."
}

variable "manager1_local_storage" {
  type        = bool
  default     = false
  description = "Is local storage available for the specified flavor"
}

variable "manager_replicates" {
  type        = number
  default     = 2
  description = "Number of manager replicates"
}

variable "manager_fips" {
  type        = number
  default     = 2
  description = "Number of fips to bind to managers, not including manager1"
}

variable "manager_flavor" {
  type        = string
  description = "Flavor of VM to allocate for redundant managers"
}

variable "manager_local_storage" {
  type        = bool
  default     = false
  description = "Is local storage available for the specified flavor"
}

variable "manager_size" {
  type        = number
  default     = 20
  description = "Size in GB of manager disk"
}

variable "manager_swap_size" {
  type        = number
  default     = 0
  description = "Swap space to allocate on manager nodes"
}

variable "manager_additional_volumes" {
  type        = list(map(string))
  default     = []
  description = "List of maps of paths keyed on UUIDs to mount to respective manager replicas"
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
  description = "List of shell commands to run on each node during init (including all workers)"
}

variable "configs" {
  type        = list(map(string))
  default     = []
  description = "List of maps to content to write to node before init (including all workers). See https://cloudinit.readthedocs.io/en/latest/topics/modules.html#write-files"
}

variable "docker_conf_master1" {
  type        = map(any)
  default     = {}
  description = "Docker daemon configuration. https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file"
}

variable "docker_conf_masters" {
  type        = map(any)
  default     = {}
  description = "Docker daemon configuration. https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file"
}

variable "master1_labels" {
  type        = map(string)
  default     = {}
  description = "Node labels for master1"
}

variable "master_labels" {
  type        = map(string)
  default     = {}
  description = "Node labels for masters"
}

variable "worker_flavors" {
  type = map(object({
    docker_conf      = map(any)          # Map of daemon config options. See var.docker_conf_master1.
    labels           = map(string)       # Map of node labels
    size             = number            # Hard drive allocation size
    configs          = list(map(string)) # List of maps to content to write to node before init. See https://cloudinit.readthedocs.io/en/latest/topics/modules.html#write-files"
    count            = number            # Number of replicas
    node_flavor      = string            # Openstack VM flavor name
    init-cmds        = list(string)      # List of shell commands to run on each node during init
    local_storage    = bool              # flavor supports local storage
    swap_size        = number            # Size of swap disk to allocate
    networks         = list(string)      # List of networks to attach to node
    addition_volumes = list(string)      # List of volume UUIDs to mount
  }))
  default     = {}
  description = "Docker daemon configuration. https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file"
}