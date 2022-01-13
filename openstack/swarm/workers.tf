resource "openstack_compute_instance_v2" "worker" {
  for_each        = local.workers
  name            = each.key
  flavor_name     = coalesce(each.value.flavor_name, var.manager_flavor)
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.id])
  key_pair        = var.key_pair
  user_data       = local.cloud-init[each.key]
  image_id        = local.image_id

  dynamic "personality" {
    for_each = merge(var.configs, each.value.configs)
    content {
      file    = personality.key
      content = personality.value
    }
  }

  personality {
    content = jsonencode(merge(each.value.docker_conf, {
      label = [for k, v in merge({
        node_flavor   = coalesce(each.value.node_flavor, var.manager_flavor)
        name          = each.key
        worker_flavor = each.value.worker_flavor
      }, each.value.labels) : "${k}=${v}"]
    }))
    file = "/etc/docker/daemon.json"
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = coalesce(each.value.size, 20) # TODO mount performant disk to docker volume root
    boot_index            = 0
    destination_type      = "local"
    delete_on_termination = true
  }

  # TODO mount fast drive to /var/lib/docker for docker data

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