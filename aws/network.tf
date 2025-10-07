# https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
module "vpc" { # https://github.com/terraform-aws-modules/terraform-aws-vpc/
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}${local.name_suffix}"
  cidr = "10.0.0.0/16"

  azs = data.aws_availability_zones.available.names

  # https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  map_public_ip_on_launch = true

  database_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  database_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  enable_nat_gateway           = true
  enable_vpn_gateway           = true
  enable_dns_hostnames         = true
  enable_dns_support           = true
  create_database_subnet_group = true

  vpc_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = {
    Terraform   = "true"
    Environment = local.instance
  }
}

resource "aws_route53_zone" "local" {
  name = "local"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}