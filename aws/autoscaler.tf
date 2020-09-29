# https://github.com/terraform-aws-modules/terraform-aws-eks/tree/master/examples/irsa
# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/324

resource "aws_iam_user" "autoscaler" {
  name = "autoscaler"
  path = "/${local.instance}/"
}

data "aws_iam_policy_document" "autoscaler" {
  statement {
    sid    = "EKSAutoscaler"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "autoscaler" {
  name        = "autoscaler"
  path        = "/${local.instance}/"
  description = "Autoscaler cluster policy"

  policy = data.aws_iam_policy_document.autoscaler.json
}

resource "aws_iam_user_policy_attachment" "autoscaler" {
  user       = aws_iam_user.autoscaler.name
  policy_arn = aws_iam_policy.autoscaler.arn
}

resource "aws_iam_access_key" "autoscaler" {
  user = aws_iam_user.autoscaler.name
}

resource "kubernetes_service_account" "autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
}

resource "kubernetes_cluster_role" "autoscaler" {
  metadata {
    name = "cluster-autoscaler"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
  rule {
    api_groups = [""]
    resources = [
      "events",
      "endpoints",
    ]
    verbs = [
      "create",
      "patch",
    ]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }
  rule {
    api_groups     = [""]
    resources      = ["endpoints"]
    resource_names = ["cluster-autoscaler"]
    verbs = [
      "get",
      "update",
    ]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs = [
      "watch",
      "list",
      "get",
      "update",
    ]
  }
  rule {
    api_groups = [""]
    resources = [
      "pods",
      "services",
      "replicationcontrollers",
      "persistentvolumeclaims",
      "persistentvolumes",
    ]
    verbs = [
      "watch",
      "list",
      "get",
    ]
  }
  rule {
    api_groups = ["extensions"]
    resources = [
      "replicasets",
      "daemonsets",
    ]
    verbs = [
      "watch",
      "list",
      "get",
    ]
  }
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs = [
      "watch",
      "list",
    ]
  }
  rule {
    api_groups = ["apps"]
    resources = [
      "statefulsets",
      "replicasets",
      "daemonsets",
    ]
    verbs = [
      "watch",
      "list",
      "get",
    ]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources = [
      "storageclasses",
      "csinodes",
    ]
    verbs = [
      "watch",
      "list",
      "get",
    ]
  }
  rule {
    api_groups = [
      "batch",
      "extensions",
    ]
    resources = ["jobs"]
    verbs = [
      "get",
      "list",
      "watch",
      "patch",
    ]
  }
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create"]
  }
  rule {
    api_groups     = ["coordination.k8s.io"]
    resource_names = ["cluster-autoscaler"]
    resources      = ["leases"]
    verbs = [
      "get",
      "update",
    ]

  }
}

resource "kubernetes_role" "autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs = [
      "create",
      "list",
      "watch",
    ]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    resource_names = [
      "cluster-autoscaler-status",
      "cluster-autoscaler-priority-expander",
    ]
    verbs = [
      "delete",
      "get",
      "update",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding" "autoscaler" {
  metadata {
    name = "cluster-autoscaler"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-autoscaler"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "kube-system"
  }
}

resource "kubernetes_role_binding" "autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cluster-autoscaler"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "kube-system"
  }
}


resource "kubernetes_deployment" "autoscaler" {
  wait_for_rollout = ! var.debug
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      app = "cluster-autoscaler"
    }
    annotations = {
      "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "cluster-autoscaler"
      }
    }
    template {
      metadata {
        labels = {
          app = "cluster-autoscaler"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8085"
        }
      }
      spec {
        service_account_name            = "cluster-autoscaler"
        automount_service_account_token = true
        container {
          name  = "cluster-autoscaler"
          image = "k8s.gcr.io/autoscaling/cluster-autoscaler:v${var.autoscaler_version}" # https://github.com/kubernetes/autoscaler/releases
          command = [
            "./cluster-autoscaler",
            "--v=4",
            "--stderrthreshold=info",
            "--cloud-provider=aws",
            "--skip-nodes-with-local-storage=false",
            "--expander=least-waste",
            "--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${local.cluster_name}",
            "--balance-similar-node-groups",
            "--skip-nodes-with-system-pods=false",
            #"--scale-down-unneeded-time=5min",
          ]

          env {
            name  = "AWS_ACCESS_KEY_ID"
            value = aws_iam_access_key.autoscaler.id
          }

          env {
            name  = "AWS_SECRET_ACCESS_KEY"
            value = aws_iam_access_key.autoscaler.secret
          }

          env {
            name  = "AWS_REGION"
            value = data.aws_region.current.name
          }

          resources {
            limits {
              cpu    = "100m"
              memory = "300Mi"
            }
            requests {
              cpu    = "100m"
              memory = "300Mi"
            }
          }
          volume_mount {
            mount_path = "/etc/ssl/certs/ca-certificates.crt"
            name       = "ssl-certs"
            read_only  = true
          }
          image_pull_policy = "Always"
        }
        volume {
          name = "ssl-certs"
          host_path {
            path = "/etc/ssl/certs/ca-bundle.crt"
          }
        }
      }
    }
  }
}