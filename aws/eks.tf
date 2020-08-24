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
  network = module.vpc.vpc_id
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.17"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  manage_aws_auth               = true
  cluster_create_security_group = true
  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  worker_groups = [
    # TODO https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/spot-instances.md#using-launch-templates
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
      }, {
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
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}
