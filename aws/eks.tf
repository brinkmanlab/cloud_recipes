locals {
  instance_types       = ["c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5d.2xlarge", "c5d.4xlarge", "c5a.2xlarge", "c5a.4xlarge", "c5a.8xlarge", "c4.2xlarge", "c4.4xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5d.2xlarge", "m5d.4xlarge", "m5d.8xlarge", "m5a.2xlarge", "m5a.4xlarge", "m4.2xlarge", "m4.4xlarge"]
  large_instance_types = ["c4.8xlarge", "c5.12xlarge", "c5.9xlarge", "c5a.12xlarge", "c5a.8xlarge", "c5d.12xlarge", "c5d.9xlarge", "c5n.9xlarge", "m5.12xlarge", "m5.8xlarge", "m5a.12xlarge", "m5a.8xlarge", "m5d.12xlarge", "m5d.8xlarge", "m5n.12xlarge", "m5n.8xlarge"]

  containerd_config = <<-EOT
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        %{for registry in values(var.docker_registry_proxies)~}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${registry.hostname}"]
          endpoint = ["http://${registry.hostname}"]
        %{endfor~}
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        %{for registry in values(var.docker_registry_proxies)~}
        [plugins."io.containerd.grpc.v1.cri".registry.configs."${registry.hostname}".tls]
          insecure_skip_verify = true
        %{endfor~}
  EOT
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

   eks_managed_node_groups = {
    services = {
        name                 = "services"
        instance_types       = ["t3.xlarge"]
        capacity_type        = "ON_DEMAND"
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
                    - --node-labels=WorkClass=service,node.kubernetes.io/lifecycle=on-demand
                    - --v=${var.kubelet_verbosity}
                containerd:
                  config: |
                    ${indent(20, local.containerd_config)}
            EOT
          }
        ]
        labels = {
          WorkClass                      = "service"
          "node.kubernetes.io/lifecycle" = "on-demand"
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

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      cpu_credits                  = "unlimited"
    },
    compute = {
        name                = "compute"
        instance_types      = local.instance_types
        capacity_type       = "SPOT"
        ami_type            = "AL2023_x86_64_STANDARD"

        min_size            = 0
        max_size            = 30
        desired_size        = 1

        subnet_ids          = module.vpc.private_subnets

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
                    - --node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot
                    - --v=${var.kubelet_verbosity}
                containerd:
                  config: |
                    ${indent(20, local.containerd_config)}
            EOT
          }
        ]
        labels = {
          WorkClass                      = "compute"
          "node.kubernetes.io/lifecycle" = "spot"
        }

        tags = {
          "k8s.io/cluster-autoscaler/enabled"                                 = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}" = "true"
          "k8s.io/cluster-autoscaler/node-template/label/WorkClass"           = "compute"
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

        max_instance_lifetime        = var.max_worker_lifetime # Minimum time allowed by AWS, 168hrs,

        iam_role_additional_policies = {
          AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        }
    },
    big_compute = {
        name                       = "big-compute"
        instance_types             = local.large_instance_types
        capacity_type              = "SPOT"
        ami_type                   = "AL2023_x86_64_STANDARD"

        min_size                   = 0
        max_size                   = 30
        desired_size               = 1

        subnet_ids                 = module.vpc.private_subnets

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
                    - --node-labels=WorkClass=compute,node.kubernetes.io/lifecycle=spot
                    - --v=${var.kubelet_verbosity}
                containerd:
                  config: |
                    ${indent(20, local.containerd_config)}
            EOT
          }
        ]

        labels = {
          WorkClass                      = "compute"
          "node.kubernetes.io/lifecycle" = "spot"
        }

        tags = {
          "k8s.io/cluster-autoscaler/enabled"                                 = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}${local.name_suffix}" = "true"
          "k8s.io/cluster-autoscaler/node-template/label/WorkClass"           = "compute"
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
        max_instance_lifetime = var.max_worker_lifetime                       # Minimum time allowed by AWS, 168hrs
        iam_role_additional_policies = {
          AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        }
    }
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


