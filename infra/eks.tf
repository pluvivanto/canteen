variable "admin_cidrs" {
  type = list(string)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = "hackathon"
  kubernetes_version = "1.36"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.admin_cidrs

  enable_cluster_creator_admin_permissions = true

  addons = {
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
    aws-ebs-csi-driver = {
      configuration_values = jsonencode({
        defaultStorageClass = { enabled = true }
      })
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types                 = ["t3.large"]
      use_latest_ami_release_version = false
      min_size                       = 3
      max_size                       = 3
      desired_size                   = 3
    }
  }
}

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name                      = "ebs-csi"
  attach_aws_ebs_csi_policy = true
}
