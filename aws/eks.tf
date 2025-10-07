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

# Retrieve the latest recommended EKS optimized AMI for 1.33
data "aws_ssm_parameter" "eks_ami_1_33_al2023" {
  name = "/aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

# Launch Template for EKS node groups
resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = data.aws_ssm_parameter.eks_ami_1_33_al2023.value
  instance_type = "t3.large"

  metadata_options {
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }
}

module "eks" {
  source           = "terraform-aws-modules/eks/aws"
  version          = "21.3.1"
  name             = var.cluster_name
  endpoint_private_access = true
  endpoint_public_access  = true
  kubernetes_version  = var.cluster_version
  subnet_ids       = module.vpc.public_subnets
  vpc_id           = module.vpc.vpc_id
  iam_role_path    = "/${local.instance}/"
  enable_cluster_creator_admin_permissions = true

  enable_irsa           = true # Outputs oidc_provider_arn
  create_security_group = true
  enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

   eks_managed_node_groups = {
    services = {
        name                 = "services"
        instance_type        = "t3.xlarge"
        ami_type             = "AL2023_x86_64_STANDARD"
        min_size             = 1
        desired_size         = 1
        max_size             = var.service_worker_max
        iam_role_arn = aws_iam_role.eks_nodegroup.arn
        subnet_ids       = module.vpc.public_subnets

        bootstrap_extra_args = "--kubelet-extra-args '--node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot'" # https://github.com/awslabs/amazon-eks-ami/blob/07dd954f09084c46d8c570f010c529ea1ad48027/files/bootstrap.sh#L25

        tags = {
          "k8s.io/cluster-autoscaler/enabled"                                 = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}" = "true"
          "k8s.io/cluster-autoscaler/node-template/label/WorkClass"           = "service"
        }
        cpu_credits           = "unlimited",

        launch_template = {
          id      = aws_launch_template.eks_nodes.id
          version = "$Latest"
        }
        iam_role_additional_policies = {
          AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
          AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
          AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
          AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        }


    },
    compute = {
        name                = "compute"
        instance_types      = local.instance_types
        ami_type            = "AL2023_x86_64_STANDARD"
        min_size            = 0
        max_size            = 30
        desired_size    = 1
        iam_role_arn = aws_iam_role.eks_nodegroup.arn
        subnet_ids       = module.vpc.public_subnets

        bootstrap_extra_args = "--kubelet-extra-args '--node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot'" # https://github.com/awslabs/amazon-eks-ami/blob/07dd954f09084c46d8c570f010c529ea1ad48027/files/bootstrap.sh#L25"
        ## What else used to be in here that was moved to bootstrap_extra_args and then removed?
        ## How are these tags the same as the concat way?


        tags = {
          "k8s.io/cluster-autoscaler/enabled"                                 = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}" = "true"
          "k8s.io/cluster-autoscaler/node-template/label/WorkClass"           = "compute"
        }
        max_instance_lifetime = var.max_worker_lifetime # Minimum time allowed by AWS, 168hrs,

        launch_template = {
          id      = aws_launch_template.eks_nodes.id
          version = "$Latest"
        }
        iam_role_additional_policies = {
          AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
          AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
          AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
          AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        }
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


# IAM role for EKS Node Groups
resource "aws_iam_role" "eks_nodegroup" {
  name = "${var.cluster_name}-nodegroup-role"

  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach required managed IAM policies
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.eks_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}



module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::038742985322:user/jmcook"
      username = "jmcook"
      groups   = ["system:masters"]
    }
  ]
}

module "alb_ingress_controller" {
  depends_on = [module.eks.cluster_name]
  source  = "iplabs/alb-ingress-controller/kubernetes"
  version = "3.4.0"

  k8s_cluster_type = "eks"
  k8s_namespace    = "kube-system"

  aws_region_name  = data.aws_region.current.name
  k8s_cluster_name = module.eks.cluster_name
}