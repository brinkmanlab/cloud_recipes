locals {
  docker_cache_name = "docker-cache"
}

resource "aws_s3_bucket" "docker_cache" {
  bucket = "docker-cache-${local.instance}"
  acl    = "private"
}

resource "kubernetes_service_account" "docker_cache" {
  metadata {
    name      = local.docker_cache_name
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.docker_cache.arn
    }
  }
}

resource "aws_iam_role" "docker_cache" {
  name_prefix = local.docker_cache_name
  # data.aws_iam_policy_document cant be used here, tries to include "Resource" attribute
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "${module.eks.oidc_provider_arn}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub": "system:serviceaccount:kube-system:${local.docker_cache_name}"
          }
        }
      }
    ]
  }
  EOF
}

data "aws_iam_policy_document" "docker_cache" {
  policy_id = "docker-cache"
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [aws_s3_bucket.docker_cache.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ]
    resources = ["${aws_s3_bucket.docker_cache.arn}/*"]
  }
}

resource "aws_iam_policy" "docker_cache" {
  name        = "docker-cache"
  path        = "/${local.instance}/"
  description = "Docker image cache policy"

  policy = data.aws_iam_policy_document.docker_cache.json
}

resource "aws_iam_role_policy_attachment" "docker_cache" {
  role       = aws_iam_role.docker_cache.name
  policy_arn = aws_iam_policy.docker_cache.arn
}

resource "kubernetes_deployment" "docker_cache" {
  wait_for_rollout = ! var.debug
  metadata {
    name      = "docker-cache"
    namespace = "kube-system"
    labels = {
      App                          = local.docker_cache_name
      "app.kubernetes.io/name"     = local.docker_cache_name
      "app.kubernetes.io/instance" = local.docker_cache_name
      #"app.kubernetes.io/version" = TODO
      "app.kubernetes.io/component"  = "container-cache"
      "app.kubernetes.io/part-of"    = "kubernetes"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "docker-cache"
      }
    }
    template {
      metadata {
        labels = {
          app = "docker-cache"
        }
      }
      spec {
        service_account_name            = kubernetes_service_account.docker_cache.metadata.0.name
        automount_service_account_token = true
        container {
          name  = "docker-cache"
          image = "registry"

          port {
            name           = "docker-cache"
            container_port = 5000
          }
          # https://docs.docker.com/registry/storage-drivers/#provided-drivers
          #env { Uses node IAM role
          #  name = "accesskey"
          #}
          #env {
          #  name = "secretkey"
          #}
          env {
            name  = "REGISTRY_STORAGE_S3_REGION"
            value = data.aws_region.current.name
          }
          env {
            name  = "REGISTRY_STORAGE_S3_BUCKET"
            value = aws_s3_bucket.docker_cache.id
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "docker_cache" {
  metadata {
    name      = "docker-cache"
    namespace = "kube-system"
  }

  spec {
    max_replicas = 10
    min_replicas = 1

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "docker-cache"
    }
  }
}

resource "kubernetes_service" "docker_cache" {
  metadata {
    name      = "docker-cache"
    namespace = "kube-system"
  }
  spec {
    selector = {
      App = kubernetes_deployment.docker_cache.metadata.0.labels.App
    }
    port {
      protocol    = "TCP"
      port        = 5000
      target_port = "docker-cache"
    }

    type = "ClusterIP"
  }
}