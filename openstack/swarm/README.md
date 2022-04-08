# Openstack Docker Swarm deployment

This module establishes a minimal Docker Swarm deployment in an existing Openstack cloud.

See the [provided example](/examples/swarm/) for a demonstration of this modules use.

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_openstack"></a> [openstack](#provider\_openstack) | n/a |
| <a name="provider_sshcommand"></a> [sshcommand](#provider\_sshcommand) | 0.2.2 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_configs"></a> [configs](#input\_configs) | List of maps to content to write to node before init (including all workers). See https://cloudinit.readthedocs.io/en/latest/topics/modules.html#write-files | `list(map(string))` | `[]` | no |
| <a name="input_docker_conf_master1"></a> [docker\_conf\_master1](#input\_docker\_conf\_master1) | Docker daemon configuration. https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file | `map(any)` | `{}` | no |
| <a name="input_docker_conf_masters"></a> [docker\_conf\_masters](#input\_docker\_conf\_masters) | Docker daemon configuration. https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file | `map(any)` | `{}` | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | Name of pre-existing image to use for swarm nodes | `string` | `null` | no |
| <a name="input_image_url"></a> [image\_url](#input\_image\_url) | URL of image to base VMs on | `string` | `null` | no |
| <a name="input_init-cmds"></a> [init-cmds](#input\_init-cmds) | List of shell commands to run on each node during init (including all workers) | `list(string)` | `[]` | no |
| <a name="input_key_pair"></a> [key\_pair](#input\_key\_pair) | Name of key pair to load into VMs | `string` | n/a | yes |
| <a name="input_manager1_flavor"></a> [manager1\_flavor](#input\_manager1\_flavor) | Flavor of VM to allocate for manager1. Should be a persistent node. | `string` | n/a | yes |
| <a name="input_manager1_local_storage"></a> [manager1\_local\_storage](#input\_manager1\_local\_storage) | Is local storage available for the specified flavor | `bool` | `false` | no |
| <a name="input_manager_additional_volumes"></a> [manager\_additional\_volumes](#input\_manager\_additional\_volumes) | List of maps of paths keyed on UUIDs to mount to respective manager replicas | `list(map(string))` | `[]` | no |
| <a name="input_manager_fips"></a> [manager\_fips](#input\_manager\_fips) | Number of fips to bind to managers, not including manager1 | `number` | `2` | no |
| <a name="input_manager_flavor"></a> [manager\_flavor](#input\_manager\_flavor) | Flavor of VM to allocate for redundant managers | `string` | n/a | yes |
| <a name="input_manager_local_storage"></a> [manager\_local\_storage](#input\_manager\_local\_storage) | Is local storage available for the specified flavor | `bool` | `false` | no |
| <a name="input_manager_replicates"></a> [manager\_replicates](#input\_manager\_replicates) | Number of manager replicates | `number` | `2` | no |
| <a name="input_manager_size"></a> [manager\_size](#input\_manager\_size) | Size in GB of manager disk | `number` | `20` | no |
| <a name="input_manager_swap_size"></a> [manager\_swap\_size](#input\_manager\_swap\_size) | Swap space to allocate on manager nodes | `number` | `0` | no |
| <a name="input_master1_labels"></a> [master1\_labels](#input\_master1\_labels) | Node labels for master1 | `map(string)` | `{}` | no |
| <a name="input_master_labels"></a> [master\_labels](#input\_master\_labels) | Node labels for masters | `map(string)` | `{}` | no |
| <a name="input_private_key"></a> [private\_key](#input\_private\_key) | Private key contents of key\_pair | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Name of private network to register nodes on | `string` | n/a | yes |
| <a name="input_public_network"></a> [public\_network](#input\_public\_network) | Name of public network to register manager1 fip | `string` | `"Public-Network"` | no |
| <a name="input_sec_groups"></a> [sec\_groups](#input\_sec\_groups) | List of security group ids to attach to engine nodes | `list(string)` | `[]` | no |
| <a name="input_vm_user"></a> [vm\_user](#input\_vm\_user) | User name associated with private key | `string` | n/a | yes |
| <a name="input_worker_flavors"></a> [worker\_flavors](#input\_worker\_flavors) | Docker daemon configuration. https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file | <pre>map(object({<br>    docker_conf      = map(any)          # Map of daemon config options. See var.docker_conf_master1.<br>    labels           = map(string)       # Map of node labels<br>    size             = number            # Hard drive allocation size<br>    configs          = list(map(string)) # List of maps to content to write to node before init. See https://cloudinit.readthedocs.io/en/latest/topics/modules.html#write-files"<br>    count            = number            # Number of replicas<br>    node_flavor      = string            # Openstack VM flavor name<br>    init-cmds        = list(string)      # List of shell commands to run on each node during init<br>    local_storage    = bool              # flavor supports local storage<br>    swap_size        = number            # Size of swap disk to allocate<br>    networks         = list(string)      # List of networks to attach to node<br>    addition_volumes = list(string)      # List of volume UUIDs to mount<br>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_manager1"></a> [manager1](#output\_manager1) | n/a |
| <a name="output_manager1_fip"></a> [manager1\_fip](#output\_manager1\_fip) | n/a |
| <a name="output_manager_token"></a> [manager\_token](#output\_manager\_token) | n/a |
| <a name="output_managers"></a> [managers](#output\_managers) | n/a |
| <a name="output_managers_fip"></a> [managers\_fip](#output\_managers\_fip) | n/a |
| <a name="output_worker_token"></a> [worker\_token](#output\_worker\_token) | n/a |
| <a name="output_workers"></a> [workers](#output\_workers) | n/a |

## Resources

| Name | Type |
|------|------|
| [openstack_compute_floatingip_associate_v2.manager](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_floatingip_associate_v2) | resource |
| [openstack_compute_floatingip_associate_v2.manager1](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_floatingip_associate_v2) | resource |
| [openstack_compute_instance_v2.manager](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_instance_v2.manager1](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_instance_v2.worker](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_servergroup_v2.managers](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_servergroup_v2) | resource |
| [openstack_images_image_v2.engine](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/images_image_v2) | resource |
| [openstack_networking_floatingip_v2.manager](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2) | resource |
| [openstack_networking_floatingip_v2.manager1](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2) | resource |
| [openstack_networking_secgroup_rule_v2.cluster_management_ip4](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.cluster_management_ip6](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.node_communication_ip4_tcp](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.node_communication_ip4_udp](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.node_communication_ip6_tcp](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.node_communication_ip6_udp](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.overlay_network_ip4](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.overlay_network_ip6](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_rule_v2.ssh_ip4](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_v2.docker_engine](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2) | resource |
| [sshcommand_command.init_manager](https://registry.terraform.io/providers/invidian/sshcommand/0.2.2/docs/resources/command) | resource |
| [sshcommand_command.init_swarm](https://registry.terraform.io/providers/invidian/sshcommand/0.2.2/docs/resources/command) | resource |
| [sshcommand_command.manager_token](https://registry.terraform.io/providers/invidian/sshcommand/0.2.2/docs/resources/command) | resource |
| [sshcommand_command.worker_token](https://registry.terraform.io/providers/invidian/sshcommand/0.2.2/docs/resources/command) | resource |
| [openstack_images_image_v2.engine](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/images_image_v2) | data source |
<!-- END_TF_DOCS -->