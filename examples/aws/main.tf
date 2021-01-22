provider "aws" {
  region = "us-west-2"
}

module "cloud" {
  source       = "../../aws"
  cluster_name = "example"
}

data "aws_eks_cluster" "cluster" {
  name = module.cloud.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.cloud.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "cvmfs" {
  source = "../../util/k8s/cvmfs"
  cvmfs_keys = {
    "microbedb.brinkmanlab.ca" = file("microbedb.brinkmanlab.ca.pub")
  }
  servers = ["http://stratum-0.brinkmanlab.ca/cvmfs/@fqrn@"]
}

resource "kubernetes_persistent_volume_claim" "repo" {
  wait_until_bound = false
  metadata {
    name      = "microbedb.brinkmanlab.ca"
    namespace = "cvmfs"
  }
  spec {
    access_modes       = ["ReadOnlyMany"]
    storage_class_name = module.cvmfs.storageclasses["microbedb.brinkmanlab.ca"].metadata.0.name
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_job" "test" {
  metadata {
    name      = "test"
    namespace = "cvmfs"
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "test"
          image   = "alpine"
          command = ["ls", "-l", "/cvmfs"]
          volume_mount {
            mount_path = "/cvmfs"
            name       = "cvmfs"
            read_only  = true
          }
        }
        node_selector = {
          WorkClass = "service"
        }
        volume {
          name = "cvmfs"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.repo.metadata.0.name
          }
        }
        restart_policy = "Never"
      }
    }
  }
}