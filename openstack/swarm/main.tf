locals {
  manager_token  = trimspace(sshcommand_command.manager_token.result)
  worker_token   = trimspace(sshcommand_command.worker_token.result)
  manager_prefix = "swarm_manager"
  worker_prefix  = "swarm_worker_"
  image_id       = var.image_name == null ? openstack_images_image_v2.engine[0].id : data.openstack_images_image_v2.engine[0].id
  signal         = "/tmp/ready_signal"
  cloud-init = { for n in concat(keys(local.workers), [for i in range(1, var.manager_replicates + 2) : "${local.manager_prefix}${i}"]) : n => join("\n", ["#cloud-config", yamlencode({
    # https://cloudinit.readthedocs.io/en/latest/topics/examples.html#run-commands-on-first-boot
    runcmd : concat([
      # TODO configure swap space
      "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo",
      "dnf update -y",
      "yum install -y docker-ce docker-ce-cli containerd.io",
      "systemctl enable docker",
      "systemctl start docker",
      "groupadd docker",
      "usermod -aG docker ${var.vm_user}",
      ], var.init-cmds, try(local.workers[n]["init-cmds"], []), [
      "touch ${local.signal}",
    ])
  })]) }
  workers = merge([for n, v in var.worker_flavors : zipmap([for i in range(1, v.count + 1) : "${local.worker_prefix}${n}${i}"], [for i in range(v.count) : merge({ worker_flavor : n }, v)])]...)
}

data "openstack_images_image_v2" "engine" {
  count = var.image_name == null ? 0 : 1
  name  = var.image_name
}

resource "openstack_images_image_v2" "engine" {
  count            = var.image_url == null ? 0 : 1
  name             = "docker-engine"
  image_source_url = var.image_url
  container_format = "bare"
  disk_format      = "qcow2"
  web_download     = true
  visibility       = "private"
}

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
      }, lookup(var.docker_conf_master1, "label", {})) : "${k}=${v}"]
    }))
    file = "/etc/docker/daemon.json"
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = var.manager_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
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

resource "sshcommand_command" "manager_token" {
  depends_on  = [sshcommand_command.init_manager]
  host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command     = "docker swarm join-token -q manager"
  private_key = var.private_key
  user        = var.vm_user
}

resource "sshcommand_command" "worker_token" {
  depends_on  = [sshcommand_command.init_manager]
  host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command     = "docker swarm join-token -q worker"
  private_key = var.private_key
  user        = var.vm_user
}

resource "openstack_networking_floatingip_v2" "manager1" {
  description = "docker-engine.cedar.brinkmanlab.ca"
  pool        = "Public-Network"
}

resource "openstack_compute_floatingip_associate_v2" "manager1" {
  floating_ip = openstack_networking_floatingip_v2.manager1.address
  instance_id = openstack_compute_instance_v2.manager1.id
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
    file    = "/etc/cvmfs/default.local"
    content = file("${path.module}/default.local")
  }

  personality {
    content = jsonencode(merge(var.docker_conf_masters, {
      label = [for k, v in merge({
        node_flavor = var.manager_flavor
        name        = "${local.manager_prefix}${count.index + 2}"
      }, lookup(var.docker_conf_masters, "label", {})) : "${k}=${v}"]
    }))
    file = "/etc/docker/daemon.json"
  }

  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = var.manager_size
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
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

resource "openstack_compute_instance_v2" "worker" {
  for_each        = local.workers
  name            = each.key
  flavor_name     = coalesce(each.value.flavor_name, var.manager_flavor)
  security_groups = concat(var.sec_groups, [openstack_networking_secgroup_v2.docker_engine.id])
  key_pair        = var.key_pair
  user_data       = local.cloud-init[each.key]

  dynamic "personality" {
    for_each = merge(var.configs, each.value.configs)
    content {
      file    = personality.key
      content = personality.value
    }
  }

  personality {
    file    = "/etc/cvmfs/default.local"
    content = file("${path.module}/default.local")
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
    destination_type      = "volume"
    delete_on_termination = true
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