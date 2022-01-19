locals {
  manager_token  = trimspace(sshcommand_command.manager_token.result)
  worker_token   = trimspace(sshcommand_command.worker_token.result)
  manager_prefix = "swarm_manager"
  worker_prefix  = "swarm_worker_"
  image_id       = var.image_name == null ? openstack_images_image_v2.engine[0].id : data.openstack_images_image_v2.engine[0].id
  signal         = "/tmp/ready_signal"
  manager_mounts = { for i in range(1, var.manager_replicates + 2) : "${local.manager_prefix}${i}" => [for k, v in try(var.manager_additional_volumes[i], []) : ["/dev/disk/by-id/virtio-${substr(k, 0, 20)}", v]] }
  workers        = merge([for n, v in var.worker_flavors : zipmap([for i in range(1, v.count + 1) : "${local.worker_prefix}${n}${i}"], [for i in range(v.count) : merge(v, { worker_flavor : n })])]...)
  cloud-init = { for n in concat(keys(local.workers), [for i in range(1, var.manager_replicates + 2) : "${local.manager_prefix}${i}"]) : n => join("\n", ["#cloud-config", yamlencode({
    #yum_repos : {
    #  aventer-rel : {
    #    name    = "AVENTER stable repository $releasever"
    #    baseurl = "http://rpm.aventer.biz/CentOS/$releasever/$basearch/"
    #    enabled = 1
    #    gpgkey  = "https://www.aventer.biz/CentOS/support_aventer.asc"
    #  }
    #}
    # https://www.freedesktop.org/software/systemd/man/systemd.mount.html#x-systemd.makefs
    mount_default_fields : ["none", "none", "ext4", "defaults,nofail,x-systemd.makefs,x-systemd.requires=cloud-init.service", "0", "2"]
    mounts : concat([
      # TODO https://docs.docker.com/storage/storagedriver/device-mapper-driver/
      ["vdb", "/var/lib/docker"],
    ], try(local.manager_mounts[n], [for k, v in local.workers[n]["additional_volumes"] : ["/dev/disk/by-id/virtio-${substr(k, 0, 20)}", v]], []))
    # https://cloudinit.readthedocs.io/en/latest/topics/examples.html#run-commands-on-first-boot
    runcmd : concat(
      [
        "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo",
        "dnf update -y",
        "yum install -y docker-ce docker-ce-cli containerd.io", # rexray",
        "systemctl enable docker",
        "systemctl start docker",
        "groupadd docker",
        "usermod -aG docker ${var.vm_user}",
        ], var.init-cmds, try(local.workers[n]["init-cmds"], []), [
        "touch ${local.signal}",
    ])
  })]) }
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

resource "sshcommand_command" "manager_token" {
  depends_on  = [sshcommand_command.init_swarm]
  host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command     = "docker swarm join-token -q manager #${sshcommand_command.init_swarm.id}"
  private_key = var.private_key
  user        = var.vm_user
}

resource "sshcommand_command" "worker_token" {
  depends_on  = [sshcommand_command.init_swarm]
  host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command     = "docker swarm join-token -q worker #${sshcommand_command.init_swarm.id}"
  private_key = var.private_key
  user        = var.vm_user
}
