output "manager_token" {
  value = local.manager_token
}

output "worker_token" {
  value = local.worker_token
}

output "manager1" {
  value = openstack_compute_instance_v2.manager1
}

output "managers" {
  value = openstack_compute_instance_v2.manager
}

output "workers" {
  value = openstack_compute_instance_v2.worker
}

output "manager1_fip" {
  value = openstack_networking_floatingip_v2.manager1
}

output "managers_fip" {
  value = openstack_networking_floatingip_v2.manager
}