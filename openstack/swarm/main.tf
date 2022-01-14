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
      #TODO this needs work to skip/init swap
      "lsblk -ndpo NAME | while read path; do if [[ ! -e $${path}1 ]]; then parted -a optimal $${path} mklabel gpt mkpart primary 0% 100% && mkfs.ext4 $${path}1 && echo \"$${path} /var/lib/docker ext4 defaults 0 0\" >> /etc/fstab; fi; done",
      "mount -a",
      "systemctl daemon-reload",
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

resource "sshcommand_command" "manager_token" {
  depends_on  = [sshcommand_command.init_manager]
  host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command     = "docker swarm join-token -q manager #${openstack_compute_instance_v2.manager1.id}"
  private_key = var.private_key
  user        = var.vm_user
}

resource "sshcommand_command" "worker_token" {
  depends_on  = [sshcommand_command.init_manager]
  host        = openstack_compute_floatingip_associate_v2.manager1.floating_ip
  command     = "docker swarm join-token -q worker #${openstack_compute_instance_v2.manager1.id}"
  private_key = var.private_key
  user        = var.vm_user
}
