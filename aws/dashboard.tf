# TODO convert chart to terraform

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