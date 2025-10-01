# Data sources to get cluster info
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Kubernetes provider — use alias to prevent conflicts
provider "kubernetes" {
  alias                  = "eks"
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  depends_on = [module.eks] # wait until cluster exists
}

# Optional: Wait for at least 1 node to be ready
resource "null_resource" "wait_for_nodes" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig <(aws eks update-kubeconfig --name ${module.eks.cluster_name}) wait --for=condition=Ready nodes --all --timeout=600s"
  }
  depends_on = [module.eks]
}

# ALB Ingress Controller
module "alb_ingress_controller" {
  source  = "iplabs/alb-ingress-controller/kubernetes"
  version = "3.4.0"

  providers = {
    kubernetes = kubernetes.eks
  }

  k8s_cluster_type = "eks"
  k8s_namespace    = "kube-system"
  aws_region_name  = data.aws_region.current.name
  k8s_cluster_name = module.eks.cluster_name

  iam_service_account_role_arn = module.eks.iam_oidc_provider_arn

  depends_on = [module.eks.cluster_name, null_resource.wait_for_nodes]
}
