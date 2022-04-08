# Docker Swarm Ingress

This module provides a HAProxy deployment to manage service ingress into the swarm network.

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_docker"></a> [docker](#provider\_docker) | n/a |

## Inputs

No inputs.

## Outputs

No outputs.

## Resources

| Name | Type |
|------|------|
| [docker_config.haproxy](https://registry.terraform.io/providers/hashicorp/docker/latest/docs/resources/config) | resource |
| [docker_service.lb](https://registry.terraform.io/providers/hashicorp/docker/latest/docs/resources/service) | resource |
| [docker_network.ingress](https://registry.terraform.io/providers/hashicorp/docker/latest/docs/data-sources/network) | data source |
<!-- END_TF_DOCS -->