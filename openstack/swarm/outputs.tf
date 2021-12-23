output "address" {
  value = openstack_networking_floatingip_v2.manager1.address
}

output "manager_token" {
  value = local.manager_token
}

output "worker_token" {
  value = local.worker_token
}