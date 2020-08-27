data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# TODO https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html
# Allow users with Admin role