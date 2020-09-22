# TODO convert to terraform https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

resource "helm_release" "dashboard" {
  name       = "dashboard-chart"
  chart      = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  namespace  = "kube-system"

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }
  depends_on = [module.eks.cluster_id]
}