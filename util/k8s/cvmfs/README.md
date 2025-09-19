# Kubernetes CVMFS CSI driver

Translated from https://github.com/cernops/cvmfs-csi and https://github.com/CloudVE/galaxy-cvmfs-csi-helm

This module provides all the necessary resources to deploy a CVMFS CSI driver into a Kubernetes cluster.

Persistent volume claims can then be created referencing a storage class output by this module (`local.microbedb_storage_class`):
```hcl
resource "kubernetes_persistent_volume_claim" "microbedb" {
  wait_until_bound = false
  metadata {
    generate_name = "microbedb-"
    namespace = kubernetes_namespace.instance.metadata.0.name
  }
  spec {
    access_modes       = ["ReadOnlyMany"]
    storage_class_name = module.cvmfs.storageclasses[local.microbedb_storage_class].metadata.0.name
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_csi_attacher_tag"></a> [csi\_attacher\_tag](#input\_csi\_attacher\_tag) | Tag for CSI Attacher image | `string` | `"v3.0.0"` | no |
| <a name="input_csi_node_driver_tag"></a> [csi\_node\_driver\_tag](#input\_csi\_node\_driver\_tag) | Tag for CSI Node Driver image | `string` | `"v2.0.1"` | no |
| <a name="input_csi_provisioner_tag"></a> [csi\_provisioner\_tag](#input\_csi\_provisioner\_tag) | Tag for CSI Provisioner image | `string` | `"v2.0.2"` | no |
| <a name="input_cvmfs_csi_driver"></a> [cvmfs\_csi\_driver](#input\_cvmfs\_csi\_driver) | CSI driver image | `string` | `"brinkmanlab/csi-cvmfsplugin"` | no |
| <a name="input_cvmfs_csi_tag"></a> [cvmfs\_csi\_tag](#input\_cvmfs\_csi\_tag) | Tag for cvmfs\_csi\_driver image | `string` | `"1.2.0"` | no |
| <a name="input_cvmfs_keys"></a> [cvmfs\_keys](#input\_cvmfs\_keys) | CVMFS Repository public keys keyed on repo name | `map(string)` | n/a | yes |
| <a name="input_cvmfs_repos"></a> [cvmfs\_repos](#input\_cvmfs\_repos) | CVMFS Repositories to mount. Tag defaults to 'trunk'. | <pre>map(object({<br/>    repo : string<br/>    tag : string<br/>  }))</pre> | `{}` | no |
| <a name="input_extra_config"></a> [extra\_config](#input\_extra\_config) | Extra CVMFS Key-values to include in default local | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Instance of kubernetes\_namespace to provision instance resources under | `any` | `null` | no |
| <a name="input_servers"></a> [servers](#input\_servers) | Set of servers as provided to CVMFS\_SERVER\_URL | `set(string)` | `[]` | no |
| <a name="input_stratum0s"></a> [stratum0s](#input\_stratum0s) | Set of stratum-0 servers to fetch stratum-1 server lists from for CVMFS\_SERVER\_URL | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_storageclasses"></a> [storageclasses](#output\_storageclasses) | Map of kubernetes\_storage\_class instances, keyed on repo key |

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.attacher](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.nodeplugin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.attacher](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.nodeplugin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_config_map.config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.repo_keys](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_csi_driver.driver](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/csi_driver) | resource |
| [kubernetes_daemonset.plugin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/daemonset) | resource |
| [kubernetes_deployment.attacher](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_namespace.cvmfs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_role.cvmfs_provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role_binding.provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_service.provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service_account.attacher](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.nodeplugin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_stateful_set.provisioner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/stateful_set) | resource |
| [kubernetes_storage_class.repos](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class) | resource |
| [http_http.stratum0_info](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
<!-- END_TF_DOCS -->