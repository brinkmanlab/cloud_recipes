locals {
  autoscaler_tag = [
    {
      key                 = "k8s.io/cluster-autoscaler/enabled"
      propagate_at_launch = "false"
      value               = "true"
    },
    {
      key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}"
      propagate_at_launch = "false"
      value               = "true"
    },
  ]
  network              = module.vpc.vpc_id
  instance_types       = ["c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5d.2xlarge", "c5d.4xlarge", "c5a.2xlarge", "c5a.4xlarge", "c5a.8xlarge", "c4.2xlarge", "c4.4xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5d.2xlarge", "m5d.4xlarge", "m5d.8xlarge", "m5a.2xlarge", "m5a.4xlarge", "m4.2xlarge", "m4.4xlarge"]
  large_instance_types = ["c4.8xlarge", "c5.12xlarge", "c5.9xlarge", "c5a.12xlarge", "c5a.8xlarge", "c5d.12xlarge", "c5d.9xlarge", "c5n.9xlarge", "m5.12xlarge", "m5.8xlarge", "m5a.12xlarge", "m5a.8xlarge", "m5d.12xlarge", "m5d.8xlarge", "m5n.12xlarge", "m5n.8xlarge"]

  docker_json = jsonencode({ # https://github.com/awslabs/amazon-eks-ami/blob/master/files/docker-daemon.json
    "bridge" : "none",
    "log-driver" : "json-file",
    "log-opts" : {
      "max-size" : "10m",
      "max-file" : "10"
    },
    "live-restore" : true,
    "max-concurrent-downloads" : 10
    #"registry-mirrors" : ["http://${local.docker_cache_url}:5000"] # https://docs.docker.com/registry/recipes/mirror/#configure-the-cache
    "insecure-registries" : values(var.docker_registry_proxies).*.hostname # https://docs.docker.com/registry/insecure/#deploy-a-plain-http-registry
  })
}

module "eks" {
  source           = "terraform-aws-modules/eks/aws"
  cluster_name     = var.cluster_name
  cluster_version  = var.cluster_version
  subnets          = module.vpc.private_subnets
  vpc_id           = module.vpc.vpc_id
  write_kubeconfig = false
  iam_path         = "/${local.instance}/"

  enable_irsa                   = true # Outputs oidc_provider_arn
  manage_aws_auth               = true
  cluster_create_security_group = true
  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  map_accounts                  = var.map_accounts
  map_roles                     = var.map_roles
  map_users                     = var.map_users

  worker_groups_launch_template = [
    # https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/spot-instances.md#using-launch-templates
    {
      name                 = "services"
      instance_type        = "t3.xlarge"
      asg_min_size         = 1
      asg_desired_capacity = 1
      asg_max_size         = 10

      kubelet_extra_args = "--node-labels=WorkClass=service"
      tags = concat(local.autoscaler_tag, [{
        key                 = "k8s.io/cluster-autoscaler/node-template/label/WorkClass"
        propagate_at_launch = "true"
        value               = "service"
      }, ])
      cpu_credits          = "unlimited"
      bootstrap_extra_args = "--docker-config-json '${local.docker_json}' --kubelet-extra-args '--v=${var.kublet_verbosity}'" # https://github.com/awslabs/amazon-eks-ami/blob/07dd954f09084c46d8c570f010c529ea1ad48027/files/bootstrap.sh#L25
    },
    {
      name                    = "compute"
      override_instance_types = local.instance_types
      spot_instance_pools     = length(local.instance_types) # Max 20
      asg_min_size            = 0
      asg_max_size            = 30
      asg_desired_capacity    = 1
      kubelet_extra_args      = "--node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot"
      tags = concat(local.autoscaler_tag, [{
        key                 = "k8s.io/cluster-autoscaler/node-template/label/WorkClass"
        propagate_at_launch = "true"
        value               = "compute"
      }, ])
      max_instance_lifetime = var.max_worker_lifetime                       # Minimum time allowed by AWS, 168hrs
      bootstrap_extra_args  = "--docker-config-json '${local.docker_json}'" # https://github.com/awslabs/amazon-eks-ami/blob/07dd954f09084c46d8c570f010c529ea1ad48027/files/bootstrap.sh#L25
    },
    {
      name                    = "big-compute"
      override_instance_types = local.large_instance_types
      spot_instance_pools     = length(local.large_instance_types) # Max 20
      asg_min_size            = 0
      asg_max_size            = 30
      asg_desired_capacity    = 1
      kubelet_extra_args      = "--node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot"
      tags = concat(local.autoscaler_tag, [{
        key                 = "k8s.io/cluster-autoscaler/node-template/label/WorkClass"
        propagate_at_launch = "true"
        value               = "compute"
      }, ])
      max_instance_lifetime = var.max_worker_lifetime                       # Minimum time allowed by AWS, 168hrs
      bootstrap_extra_args  = "--docker-config-json '${local.docker_json}'" # https://github.com/awslabs/amazon-eks-ami/blob/07dd954f09084c46d8c570f010c529ea1ad48027/files/bootstrap.sh#L25
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
