output "eks" {
  value       = module.eks
  description = "EKS submodule output"
}

output "vpc" {
  value       = module.vpc
  description = "VPC submodule output"
}

output "local_zone" {
  value       = aws_route53_zone.local
  description = "'*.local' DNS zone"
}