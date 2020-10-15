locals {
  docker_cache_name = "docker-cache"
}

resource "aws_s3_bucket" "docker_cache" {
  bucket = "docker-cache-${local.instance}"
  acl    = "private"
}

resource "kubernetes_service_account" "docker_cache" {
  depends_on = [module.eks]
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

resource "kubernetes_secret" "docker_cache" {
  metadata {
    name      = "docker-cache-config"
    namespace = "kube-system"
  }
  data = {
    # TODO https://docs.docker.com/registry/configuration/#prometheus
    "config.yml" = <<-EOF
      version: 0.1
      log:
        fields:
          service: registry
      storage:
        cache:
          blobdescriptor: inmemory
        s3:
          region: ${data.aws_region.current.name}
          bucket: ${aws_s3_bucket.docker_cache.id}
      http:
        addr: :5000
        headers:
          X-Content-Type-Options: [nosniff]
      health:
        storagedriver:
          enabled: true
          interval: 10s
          threshold: 3
      proxy:
        remoteurl: ${var.docker_registry_proxies[0].url}
        username: ${var.docker_registry_proxies[0].username}
        password: ${var.docker_registry_proxies[0].password}
    EOF
  }
  type = "Opaque"
}

resource "kubernetes_deployment" "docker_cache" {
  depends_on       = [module.eks]
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

          #env { TODO?
          #  name = "REGISTRY_HTTP_SECRET"
          #  value =
          #}

          volume_mount {
            mount_path = "/etc/docker/registry"
            name       = "config"
            read_only  = true
          }
        }
        volume {
          name = "config"
          secret {
            secret_name = kubernetes_secret.docker_cache.metadata.0.name
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
      name        = kubernetes_deployment.docker_cache.metadata.0.name
    }
  }
}

resource "kubernetes_service" "docker_cache" {
  metadata {
    name      = "docker-cache"
    namespace = "kube-system"
    annotations = {
      # https://gist.github.com/mgoodness/1a2926f3b02d8e8149c224d25cc57dc1
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
      "service.beta.kubernetes.io/aws-load-balancer-type"     = "nlb"
    }
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

    type = "LoadBalancer"
  }
}

resource "aws_route53_record" "local" {
  zone_id = aws_route53_zone.local.zone_id
  name    = local.docker_cache_url
  type    = "CNAME"
  ttl     = "300"
  records = kubernetes_service.docker_cache.load_balancer_ingress[*].hostname
}