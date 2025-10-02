# AWS EKS Deployment

This module contains everything necessary for a pushbutton deployment of AWS EKS. 
This includes a dashboard, autoscaler, and three preconfigured compute classes.
"service", "compute", and "big-compute" are available to schedule pods by specifying them via 
`node_selector = { WorkClass = "service" }` in the pod specification. `service` is composed of t3.xlarge nodes and scales to a minimum of 1.
`compute` and `big-compute` is composed of the cheapest available spot instance nodes and scales to 0 when idle. `big-compute` has a minimum of 8 cpus.

## Use

Install the [AWS CLI tool](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), and [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html).
Ensure you are authenticating with the correct IAM user by running `aws sts get-caller-identity`. Run `aws configure` to specify the
credentials to use for deployment. The user deploying the cluster will automatically be granted admin privileges for the cluster.

Run `aws-iam-authenticator token -i <cluster name> --token-only` to get the required token for the dashboard.

Configure `kubectl` by running `aws eks --region us-east-1 update-kubeconfig --name <cluster name>`.

Services accessible via `kubectl proxy` can be listed by running `kubectl cluster-info`.
Run `kubectl proxy` and visit [here](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login) to
access the dashboard.

Updating the Kubernetes version does not update the managed add-ons deployed with it. 
See [coredns](https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html#updating-coredns-add-on), 
[kube-proxy](https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html#updating-kube-proxy-add-on),
and [aws-node](https://github.com/aws/amazon-vpc-cni-k8s/releases) daemonset upgrade information. 

Refer to the Kubernetes section for the remaining information.
See the [provided example](/examples/aws/) for a demonstration of this modules use.

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb_ingress_controller"></a> [alb\_ingress\_controller](#module\_alb\_ingress\_controller) | iplabs/alb-ingress-controller/kubernetes | 3.4.0 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.3.1 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscaler_version"></a> [autoscaler\_version](#input\_autoscaler\_version) | n/a | `string` | `"1.21.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes cluster version | `string` | `"1.32"` | no |
| <a name="input_dashboard_default_namespace"></a> [dashboard\_default\_namespace](#input\_dashboard\_default\_namespace) | The default namespace to show when logging into the dashboard | `string` | `"default"` | no |
| <a name="input_dashboard_version"></a> [dashboard\_version](#input\_dashboard\_version) | n/a | `string` | `"2.4.0"` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | n/a | `bool` | `false` | no |
| <a name="input_docker_registry_proxies"></a> [docker\_registry\_proxies](#input\_docker\_registry\_proxies) | Docker registries to proxy | <pre>map(object({<br/>    hostname = string<br/>    url      = string<br/>    username = string<br/>    password = string<br/>  }))</pre> | `{}` | no |
| <a name="input_docker_registry_version"></a> [docker\_registry\_version](#input\_docker\_registry\_version) | Image tag of docker registry | `string` | `"0.9.1"` | no |
| <a name="input_instance"></a> [instance](#input\_instance) | n/a | `string` | `""` | no |
| <a name="input_kubelet_verbosity"></a> [kubelet\_verbosity](#input\_kubelet\_verbosity) | --v option for kublet | `number` | `2` | no |
| <a name="input_map_accounts"></a> [map\_accounts](#input\_map\_accounts) | Additional AWS account numbers to add to the aws-auth configmap. ex: "777777777777" | `list(string)` | `[]` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. ex:<br/>{<br/>  rolearn  = "arn:aws:iam::66666666666:role/role1"<br/>  username = "role1"<br/>  groups   = ["system:masters"]<br/>} | <pre>list(object({<br/>    rolearn  = string<br/>    username = string<br/>    groups   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_map_users"></a> [map\_users](#input\_map\_users) | Additional IAM users to add to the aws-auth configmap. ex:<br/>{<br/>  userarn  = "arn:aws:iam::66666666666:user/user1"<br/>  username = "user1"<br/>  groups   = ["system:masters"]<br/>} | <pre>list(object({<br/>    userarn  = string<br/>    username = string<br/>    groups   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_max_worker_lifetime"></a> [max\_worker\_lifetime](#input\_max\_worker\_lifetime) | Maximum lifetime (in seconds) of compute nodes (minimum 86400) | `number` | `259200` | no |
| <a name="input_metrics_scraper_version"></a> [metrics\_scraper\_version](#input\_metrics\_scraper\_version) | n/a | `string` | `"1.0.7"` | no |
| <a name="input_metrics_server_version"></a> [metrics\_server\_version](#input\_metrics\_server\_version) | n/a | `string` | `"0.3.6"` | no |
| <a name="input_service_worker_max"></a> [service\_worker\_max](#input\_service\_worker\_max) | Maximum number of service workers | `number` | `10` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks"></a> [eks](#output\_eks) | EKS submodule output |
| <a name="output_local_zone"></a> [local\_zone](#output\_local\_zone) | '*.local' DNS zone |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | VPC submodule output |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_route53_record.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone.local](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_s3_bucket.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [kubernetes_api_service.metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/api_service) | resource |
| [kubernetes_cluster_role.aggregated_metrics_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.auth_delegator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_config_map.kube_dashboard_settings](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_deployment.autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_deployment.docker_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_deployment.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_deployment.kube_dashboard_scraper](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_deployment.metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_horizontal_pod_autoscaler.docker_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/horizontal_pod_autoscaler) | resource |
| [kubernetes_namespace.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_role.autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role_binding.auth_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_role_binding.autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_role_binding.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.docker_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.kube_dashboard_certs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.kube_dashboard_csrf](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.kube_dashboard_key_holder](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.registry_passwords](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service.docker_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service.kube_dashboard_scraper](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service.metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service_account.autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.docker_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.kube_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.autoscaler_assume_role_with_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.docker_cache_assume_role_with_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.docker_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
<!-- END_TF_DOCS -->