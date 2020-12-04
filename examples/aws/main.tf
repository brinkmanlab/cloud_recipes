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
  load_config_file       = false
}

module "cvmfs" {
  source     = "../../util/k8s/cvmfs"
  cvmfs_keys = { "microbedb.brinkmanlab.ca" : file("microbedb.brinkmanlab.ca.pub") }
  servers    = ["http://stratum-0.brinkmanlab.ca/cvmfs/@fqrn@"]
}