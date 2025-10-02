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
  version          = "21.3.1"
  name     = var.cluster_name
  endpoint_private_access = true
  endpoint_public_access  = true
  kubernetes_version  = var.cluster_version
  subnet_ids       = module.vpc.private_subnets
  vpc_id           = module.vpc.vpc_id
  iam_role_path    = "/${local.instance}/"

  enable_irsa           = true # Outputs oidc_provider_arn
  create_security_group = true
  enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_groups = {
    services = {
        name                 = "services"
        instance_types        = local.instance_types
        min_size             = 1
        desired_size         = 1
        max_size             = var.service_worker_max

        bootstrap_extra_args = "--kubelet-extra-args '--node-labels=WorkClass=service --v=${var.kubelet_verbosity}' --docker-config-json '${local.docker_json}'" # https://github.com/awslabs/amazon-eks-ami/blob/07dd954f09084c46d8c570f010c529ea1ad48027/files/bootstrap.sh#L25

        tags = {
          "k8s.io/cluster-autoscaler/enabled"                                 = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}" = "true"
          "k8s.io/cluster-autoscaler/node-template/label/WorkClass"           = "service"
        }
        cpu_credits           = "unlimited"
    },
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "alb_ingress_controller" {
  depends_on = [module.eks.cluster_name]
  source  = "iplabs/alb-ingress-controller/kubernetes"
  version = "3.4.0"

  k8s_cluster_type = "eks"
  k8s_namespace    = "kube-system"

  aws_region_name  = data.aws_region.current.name
  k8s_cluster_name = data.aws_eks_cluster.cluster.name
}