#TODO docker cache simply doesnt work for quay.io: https://github.com/moby/moby/pull/34319

locals {
  docker_cache_name = "docker-cache"
}

resource "aws_s3_bucket" "docker_cache" {
  bucket_prefix = "docker-cache-${local.instance}-"
  acl           = "private"
  force_destroy = true
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

data "aws_iam_policy_document" "docker_cache_assume_role_with_oidc" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub"
      values   = ["system:serviceaccount:kube-system:${local.docker_cache_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "docker_cache" {
  name_prefix        = local.docker_cache_name
  assume_role_policy = data.aws_iam_policy_document.docker_cache_assume_role_with_oidc.json
}

data "aws_iam_policy_document" "docker_cache" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets"
    ]
    resources = ["arn:aws:s3:::*"]
  }
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
  name_prefix = "docker-cache"
  path        = "/${local.instance}/"
  description = "Docker image cache policy"

  policy = data.aws_iam_policy_document.docker_cache.json
}

resource "aws_iam_role_policy_attachment" "docker_cache" {
  role       = aws_iam_role.docker_cache.name
  policy_arn = aws_iam_policy.docker_cache.arn
}

# TODO docker registry grabs node role and ignores service account
# https://github.com/docker/distribution/issues/3275
# https://docs.aws.amazon.com/eks/latest/userguide/restrict-ec2-credential-access.html
# Delete the following once fixed
resource "aws_iam_role_policy_attachment" "node_s3" {
  role       = module.eks.worker_iam_role_name
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
          region: ${aws_s3_bucket.docker_cache.region}
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
    EOF
  }
  type = "Opaque"
}

resource "kubernetes_secret" "registry_passwords" {
  metadata {
    name      = "registry-passwords"
    namespace = "kube-system"
  }
  data = { for k, v in var.docker_registry_proxies : k => v.password }
}

resource "kubernetes_deployment" "docker_cache" {
  for_each         = var.docker_registry_proxies
  depends_on       = [module.eks]
  wait_for_rollout = ! var.debug
  metadata {
    name      = "${local.docker_cache_name}-${each.key}"
    namespace = "kube-system"
    labels = {
      App                            = "${local.docker_cache_name}-${each.key}"
      "app.kubernetes.io/name"       = local.docker_cache_name
      "app.kubernetes.io/instance"   = "${local.docker_cache_name}-${each.key}"
      "app.kubernetes.io/version"    = "2"
      "app.kubernetes.io/component"  = "container-cache"
      "app.kubernetes.io/part-of"    = "kubernetes"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      proxying = each.value.hostname
    }
  }
  spec {
    selector {
      match_labels = {
        App = "${local.docker_cache_name}-${each.key}"
      }
    }
    template {
      metadata {
        labels = {
          App = "${local.docker_cache_name}-${each.key}"
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

          env {
            name  = "REGISTRY_STORAGE_S3_ROOTDIRECTORY"
            value = "/${each.key}/"
          }

          env {
            name  = "REGISTRY_PROXY_REMOTEURL"
            value = each.value.url
          }

          env {
            name  = "REGISTRY_PROXY_USERNAME"
            value = each.value.username
          }

          env {
            name = "REGISTRY_PROXY_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.registry_passwords.metadata.0.name
                key  = each.key
              }
            }
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
  for_each = kubernetes_deployment.docker_cache
  metadata {
    name      = each.value.metadata.0.name
    namespace = each.value.metadata.0.namespace
  }

  spec {
    max_replicas = 10
    min_replicas = 1

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = each.value.metadata.0.name
    }
  }
}

resource "kubernetes_service" "docker_cache" {
  for_each = kubernetes_deployment.docker_cache
  metadata {
    name      = each.value.metadata.0.name
    namespace = each.value.metadata.0.namespace
    annotations = {
      # https://gist.github.com/mgoodness/1a2926f3b02d8e8149c224d25cc57dc1
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
      "service.beta.kubernetes.io/aws-load-balancer-type"     = "nlb"
      proxying                                                = each.value.metadata.0.annotations.proxying
    }
  }
  spec {
    selector = {
      App = each.value.metadata.0.labels.App
    }
    port {
      protocol    = "TCP"
      port        = 5000
      target_port = "docker-cache"
    }

    type = "LoadBalancer"
  }
}

# Creates internal DNS record spoofing registry domain
resource "aws_route53_zone" "docker_cache" {
  for_each = var.docker_registry_proxies
  name     = each.value.hostname

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

data "aws_lb" "docker_cache" {
  for_each = var.docker_registry_proxies
  name     = split("-", kubernetes_service.docker_cache[each.key].load_balancer_ingress.0.hostname)[0]
}

resource "aws_route53_record" "docker_cache" {
  for_each = kubernetes_service.docker_cache
  zone_id  = aws_route53_zone.docker_cache[each.key].zone_id
  name     = each.value.metadata.0.annotations.proxying
  type     = "A"
  alias {
    evaluate_target_health = false
    name                   = "dualstack.${each.value.load_balancer_ingress.0.hostname}"
    zone_id                = data.aws_lb.docker_cache[each.key].zone_id
  }
}