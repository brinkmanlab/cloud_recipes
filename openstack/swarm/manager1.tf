resource "openstack_compute_instance_v2" "manager1" {
  name            = "${local.manager_prefix}1"
  flavor_name     = var.manager1_flavor
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.id])
  key_pair        = var.key_pair
  user_data       = local.cloud-init["${local.manager_prefix}1"]

  dynamic "personality" {
    for_each = var.configs
    content {
      file    = personality.key
      content = personality.value
    }
  }

  personality {
    content = jsonencode(merge(var.docker_conf_masters, {
      label = [for k, v in merge({
        node_flavor = var.manager_flavor
        name        = "${local.manager_prefix}1"
        ingress     = true
      }, lookup(var.docker_conf_master1, "label", {})) : "${k}=${v}"]
    }))
    file = "/etc/docker/daemon.json"
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = 20
    boot_index            = 0
    destination_type      = var.manager1_local_storage ? "local" : "volume"
    delete_on_termination = true
  }

  dynamic "block_device" {
    for_each = range(var.manager1_local_storage ? 1 : 0)
    content {
      boot_index            = -1
      delete_on_termination = true
      destination_type      = "local"
      source_type           = "blank"
      guest_format          = "swap"
      volume_size           = 64
    }
  }

  # TODO mount fast drive to /var/lib/docker for docker data
  block_device {
    boot_index            = -1
    delete_on_termination = true
    destination_type      = var.manager1_local_storage ? "local" : "volume"
    source_type           = "blank"
    volume_size           = var.manager_size
    guest_format          = "ext4"
  }

  #connection {
  #  type = "ssh"
  #  host = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  #  user = var.vm_user
  #  private_key = var.private_key
  #}
  #provisioner "remote-exec" {
  #  inline = [
  #    "until [[ -f ${local.signal} ]]; do sleep 1; done",
  #    "docker swarm init --advertise-addr ${self.access_ip_v4}",
  #  ]
  #}
}

resource "sshcommand_command" "init_manager" {
  host                  = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command               = "until [[ -f ${local.signal} ]]; do sleep 1; done; sudo docker swarm init --advertise-addr ${openstack_compute_instance_v2.manager1.access_ip_v4}"
  private_key           = var.private_key
  user                  = var.vm_user
  retry                 = true
  retry_timeout         = "10m"
  connection_timeout    = "30s"
  ignore_execute_errors = true
}

resource "openstack_networking_floatingip_v2" "manager1" {
  description = "${local.manager_prefix}1"
  pool        = var.public_network
}

resource "openstack_compute_floatingip_associate_v2" "manager1" {
  floating_ip = openstack_networking_floatingip_v2.manager1.address
  instance_id = openstack_compute_instance_v2.manager1.id
}
