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

  metadata_options {
    http_tokens                 = "required"  # Use IMDSv2
    http_put_response_hop_limit = 2           # Increase for EKS
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-node"
    }
  }
}

module "eks" {
  source           = "terraform-aws-modules/eks/aws"
  version          = "21.3.1"
  name             = var.cluster_name
  endpoint_private_access = true
  endpoint_public_access  = true
  kubernetes_version  = var.cluster_version
  subnet_ids       = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  vpc_id           = module.vpc.vpc_id
  iam_role_path    = "/${local.instance}/"
  enable_cluster_creator_admin_permissions = true

  enable_irsa           = true # Outputs oidc_provider_arn

  security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
    ingress_nodes_443 = {
      description                = "Nodes to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }
  # Node security group
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }
  enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  addons = {
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

   eks_managed_node_groups = {
    services = {
        name                 = "services"
        instance_types        = ["t3.xlarge"]
        ami_type             = "AL2023_x86_64_STANDARD"
        min_size             = 1
        desired_size         = 1
        max_size             = var.service_worker_max
        subnet_ids = module.vpc.private_subnets

        iam_role_attach_cni_policy = true
        use_custom_launch_template = false

        cloudinit_pre_nodeadm = [
          {
            content_type = "application/node.eks.aws"
            content      = <<-EOT
              apiVersion: node.eks.aws/v1alpha1
              kind: NodeConfig
              spec:
                kubelet:
                  config:
                    maxPods: 110
                  flags:
                    - --node-labels=WorkClass=service,node.kubernetes.io/lifecycle=spot
            EOT
          }
        ]
        labels = {
          WorkClass = "service"
        }

        tags = {
          "k8s.io/cluster-autoscaler/enabled"                                 = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}" = "true"
          "k8s.io/cluster-autoscaler/node-template/label/WorkClass"           = "service"
        }

        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size           = 100
              volume_type           = "gp3"
              encrypted             = true
              delete_on_termination = true
            }
          }
        }

        #cpu_credits           = "unlimited",

      launch_template_name   = aws_launch_template.eks_nodes.name
      launch_template_version = "$Latest"

        iam_role_additional_policies = {
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
#resource "aws_iam_role" "eks_nodegroup" {
#  name = "${var.cluster_name}-nodegroup-role"
#  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
#}

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
#resource "aws_iam_role_policy_attachment" "worker_node_policy" {
#  role       = aws_iam_role.eks_nodegroup.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#}

#resource "aws_iam_role_policy_attachment" "cni_policy" {
#  role       = aws_iam_role.eks_nodegroup.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#}

#resource "aws_iam_role_policy_attachment" "ecr_policy" {
#  role       = aws_iam_role.eks_nodegroup.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#}



module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::038742985322:user/jmcook"
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