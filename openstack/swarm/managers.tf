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
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.id])
  key_pair        = var.key_pair
  user_data       = local.cloud-init["${local.manager_prefix}${count.index + 2}"]

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
        name        = "${local.manager_prefix}${count.index + 2}"
        ingress     = count.index < var.manager_fips
      }, lookup(var.docker_conf_masters, "label", {})) : "${k}=${v}"]
    }))
    file = "/etc/docker/daemon.json"
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = var.manager_size
    boot_index            = 0
    destination_type      = "local"
    delete_on_termination = true
  }

  # TODO mount fast drive to /var/lib/docker for docker data

  scheduler_hints {
    group = openstack_compute_servergroup_v2.managers.id
  }

  connection {
    host        = self.access_ip_v4
    user        = var.vm_user
    private_key = var.private_key
    #certificate = var.key_cert
    bastion_host        = openstack_networking_floatingip_v2.manager1.address
    bastion_private_key = var.private_key
    bastion_user        = var.vm_user
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
  description = "manager${count.index}"
  pool        = var.public_network
}

resource "openstack_compute_floatingip_associate_v2" "manager" {
  count       = local.fip_assignments
  floating_ip = openstack_networking_floatingip_v2.manager["manager${count.index}"].address
  instance_id = openstack_compute_instance_v2.manager["manager${count.index}"].id
}