resource "openstack_networking_secgroup_v2" "docker_engine" {
  name        = "docker_engine"
  description = "Exposes ports used by Docker Swarm"
}

resource "openstack_networking_secgroup_rule_v2" "cluster_management_ip6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 2377
  port_range_max    = 2377
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "cluster_management_ip4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2377
  port_range_max    = 2377
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "node_communication_ip6_tcp" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "node_communication_ip4_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "node_communication_ip6_udp" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "udp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "node_communication_ip4_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "overlay_network_ip6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "udp"
  port_range_min    = 4789
  port_range_max    = 4789
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "overlay_network_ip4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 4789
  port_range_max    = 4789
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh_ip4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_engine.id
}
