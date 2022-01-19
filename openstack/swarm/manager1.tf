# TODO data.openstack_compute_flavor_v2.manager1.extra_specs["aggregate_instance_extra_specs:persistent"] == "true" to determine if local volumes permitted
#data "openstack_compute_flavor_v2" "manager1" {
#  name = var.manager1_flavor
#}

resource "openstack_compute_instance_v2" "manager1" {
  name            = "${local.manager_prefix}1"
  flavor_name     = var.manager1_flavor
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.name])
  key_pair        = var.key_pair
  user_data       = local.cloud-init["${local.manager_prefix}1"]
  image_id        = var.manager1_local_storage ? local.image_id : null
  tags            = []

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
    for_each = range(var.manager1_local_storage && var.manager_swap_size > 0 ? 1 : 0)
    content {
      boot_index            = -1
      delete_on_termination = true
      destination_type      = "local"
      source_type           = "blank"
      guest_format          = "swap"
      volume_size           = var.manager_swap_size
    }
  }

  block_device {
    boot_index            = -1
    delete_on_termination = true
    destination_type      = var.manager1_local_storage ? "local" : "volume"
    source_type           = "blank"
    volume_size           = var.manager_size
    guest_format          = "ext4"
  }

  dynamic "block_device" {
    for_each = var.manager_additional_volumes[0]
    content {
      boot_index       = -1
      uuid             = block_device.key
      source_type      = "volume"
      destination_type = "volume"
    }
  }

  network {
    name = var.private_network
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.managers.id
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

resource "sshcommand_command" "init_swarm" {
  host                  = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command               = "until [[ -f ${local.signal} ]]; do sleep 1; done; sudo docker swarm init --advertise-addr ${openstack_compute_instance_v2.manager1.access_ip_v4}"
  private_key           = var.private_key
  user                  = var.vm_user
  retry                 = true
  retry_timeout         = "10m"
  connection_timeout    = "30s"
  ignore_execute_errors = true
  lifecycle {
    ignore_changes = all
  }
}

resource "sshcommand_command" "init_manager" { # Rejoins manager1 to existing swarm in the event that manager1 is reinstanced
  host                  = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command               = "until [[ -f ${local.signal} ]]; do sleep 1; done; sudo docker system info | grep 'Swarm: inactive' && sudo docker swarm join --token ${local.manager_token} ${openstack_compute_instance_v2.manager[0].access_ip_v4}:2377 #${openstack_compute_instance_v2.manager1.id}"
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
