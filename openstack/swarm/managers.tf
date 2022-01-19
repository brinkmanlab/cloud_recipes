locals {
  fip_assignments = min(var.manager_fips, var.manager_replicates)
}

resource "openstack_compute_servergroup_v2" "managers" {
  name     = "${local.manager_prefix}s"
  policies = ["soft-anti-affinity"]
}

resource "openstack_compute_instance_v2" "manager" {
  count           = var.manager_replicates
  name            = "${local.manager_prefix}${count.index + 2}"
  flavor_name     = var.manager_flavor
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.name])
  key_pair        = var.key_pair
  user_data       = local.cloud-init["${local.manager_prefix}${count.index + 2}"]
  image_id        = local.image_id

  lifecycle {
    create_before_destroy = true
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = 20
    boot_index            = 0
    destination_type      = "local"
    delete_on_termination = true
  }

  dynamic "block_device" {
    for_each = range(var.manager_local_storage && var.manager_swap_size > 0 ? 1 : 0)
    content {
      boot_index            = -1
      delete_on_termination = true
      destination_type      = "local"
      source_type           = "blank"
      guest_format          = "swap"
      volume_size           = var.manager_swap_size
    }
  }

  dynamic "block_device" {
    for_each = range(var.manager_local_storage && var.manager_size > 0 ? 1 : 0)
    content {
      boot_index            = -1
      delete_on_termination = true
      destination_type      = "local"
      source_type           = "blank"
      volume_size           = var.manager_size
      guest_format          = "ext4"
    }
  }

  dynamic "block_device" {
    for_each = try(var.manager_additional_volumes[count.index + 1], [])
    content {
      boot_index       = -1
      uuid             = block_device.key
      source_type      = "volume"
      destination_type = "volume"
    }
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.managers.id
  }

  network {
    name = var.private_network
  }

  connection {
    host        = self.access_ip_v4
    user        = var.vm_user
    private_key = var.private_key
    #certificate = var.key_cert
    bastion_host = openstack_networking_floatingip_v2.manager1.address
  }

  provisioner "remote-exec" {
    inline = [
      "until [[ -f ${local.signal} ]]; do sleep 1; done",
      "sudo docker swarm join --token ${local.manager_token} ${openstack_compute_instance_v2.manager1.access_ip_v4}:2377",
    ]
  }
}

resource "openstack_networking_floatingip_v2" "manager" {
  count       = local.fip_assignments
  description = "${local.manager_prefix}${count.index + 2}"
  pool        = var.public_network
}

resource "openstack_compute_floatingip_associate_v2" "manager" {
  count       = local.fip_assignments
  floating_ip = openstack_networking_floatingip_v2.manager[count.index].address
  instance_id = openstack_compute_instance_v2.manager[count.index].id
}