output "cluster_id" {
  value = module.eks.cluster_id
}

output "worker_security_group_id" {
  value = module.eks.worker_security_group_id
}

output "database_subnet_group" {
  value = module.vpc.database_subnet_group
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "cdir_block" {
  value = module.vpc.vpc_cidr_block
}

output "vpc_id" {
  value = module.vpc.vpc_id
}