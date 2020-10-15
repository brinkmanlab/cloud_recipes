output "eks" {
  value = module.eks
}

output "vpc" {
  value = module.vpc
}

output "local_zone" {
  value = aws_route53_zone.local
}