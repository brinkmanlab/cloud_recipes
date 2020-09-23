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
  network        = module.vpc.vpc_id
  instance_types = ["c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5d.2xlarge", "c5d.4xlarge", "c5a.2xlarge", "c5a.4xlarge", "c5a.8xlarge", "c4.2xlarge", "c4.4xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5d.2xlarge", "m5d.4xlarge", "m5d.8xlarge", "m5a.2xlarge", "m5a.4xlarge", "m4.2xlarge", "m4.4xlarge"]
}

module "eks" {
  source           = "terraform-aws-modules/eks/aws"
  cluster_name     = var.cluster_name
  cluster_version  = "1.17"
  subnets          = module.vpc.private_subnets
  vpc_id           = module.vpc.vpc_id
  write_kubeconfig = false
  # TODO iam_path = "/${local.instance}/"

  manage_aws_auth               = true
  cluster_create_security_group = true
  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  worker_groups = [
    {
      name                 = "services"
      instance_type        = "t3.xlarge"
      asg_min_size         = 1
      asg_desired_capacity = 1
      asg_max_size         = 10

      kubelet_extra_args = "--node-labels=WorkClass=service"
      tags = concat(local.autoscaler_tag, [{
        key                 = "WorkClass"
        propagate_at_launch = "false"
        value               = "service"
      }, ])
      cpu_credits = "unlimited"
    }, /*{
      name                 = "compute"
      instance_type        = "c5.2xlarge"
      asg_min_size         = 0
      asg_max_size         = 30
      asg_desired_capacity = 1
      kubelet_extra_args   = "--node-labels=WorkClass=compute"
      tags = concat(local.autoscaler_tag, [{
        key                 = "WorkClass"
        propagate_at_launch = "false"
        value               = "compute"
      }, ])
      # spot_price           =
    },*/
  ]

  worker_groups_launch_template = [
    # https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/spot-instances.md#using-launch-templates
    {
      name                    = "compute"
      override_instance_types = local.instance_types
      spot_instance_pools     = length(local.instance_types) # Max 20
      asg_min_size            = 0
      asg_max_size            = 30
      asg_desired_capacity    = 1
      kubelet_extra_args      = "--node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot"
      tags = concat(local.autoscaler_tag, [{
        key                 = "WorkClass"
        propagate_at_launch = "false"
        value               = "compute"
      }, ])
      max_instance_lifetime = 604800 # Minimum time allowed by AWS, 168hrs
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
  load_config_file       = false
}
