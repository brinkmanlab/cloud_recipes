terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    sshcommand = {
      source  = "invidian/sshcommand"
      version = "0.2.2"
    }
  }
  required_version = ">= 0.15.1"
}