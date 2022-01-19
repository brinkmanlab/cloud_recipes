resource "openstack_compute_instance_v2" "worker" {
  for_each        = local.workers
  name            = each.key
  flavor_name     = coalesce(each.value.flavor_name, var.manager_flavor)
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.name])
  key_pair        = var.key_pair
  user_data       = local.cloud-init[each.key]
  image_id        = local.image_id

  lifecycle {
    create_before_destroy = true
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = 20
    boot_index            = 0
    destination_type      = each.value.local_storage ? "local" : "volume"
    delete_on_termination = true
  }

  dynamic "block_device" {
    for_each = range(each.value.local_storage && coalesce(each.value.swap_size, 0) > 0 ? 1 : 0)
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
    for_each = range(each.value.local_storage && each.value.size > 0 ? 1 : 0)
    content {
      boot_index            = -1
      delete_on_termination = true
      destination_type      = "local"
      source_type           = "blank"
      volume_size           = each.value.size
      guest_format          = "ext4"
    }
  }

  dynamic "block_device" {
    for_each = try(each.value.additional_volumes, [])
    content {
      boot_index       = -1
      uuid             = block_device.key
      source_type      = "volume"
      destination_type = "volume"
    }
  }

  dynamic "network" {
    for_each = coalesce(each.value.networks, [var.private_network])
    content {
      name = network.value
    }
  }

  connection {
    host                = self.access_ip_v4
    user                = var.vm_user
    private_key         = var.private_key
    bastion_host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
    bastion_private_key = var.private_key
    bastion_user        = var.vm_user
  }

  provisioner "remote-exec" {
    inline = [
      "until [[ -f ${local.signal} ]]; do sleep 1; done",
      "sudo docker swarm join --token ${local.worker_token} ${openstack_compute_instance_v2.manager1.access_ip_v4}:2377",
    ]
  }
}