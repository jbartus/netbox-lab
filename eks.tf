module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  count                                    = var.enable_eks ? 1 : 0
  name                                     = "lab-cluster-${data.external.whoami.result.username}"
  kubernetes_version                       = "1.33"
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    aws-ebs-csi-driver     = {}
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    spot = {
      min_size       = 3
      max_size       = 6
      desired_size   = 3
      instance_types = ["m7i.large", "m7i-flex.large", "m7a.large"]
      capacity_type  = "SPOT"
    }
  }
}

module "ebs_csi_pod_identity" {
  source                    = "terraform-aws-modules/eks-pod-identity/aws"
  count                     = var.enable_eks ? 1 : 0
  name                      = "ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    ebs-csi = {
      cluster_name    = module.eks[0].cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
}

resource "null_resource" "kubectl" {
  count      = var.enable_eks ? 1 : 0
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks[0].cluster_name}"
  }
}

resource "null_resource" "annotate_storageclass" {
  count      = var.enable_eks ? 1 : 0
  depends_on = [null_resource.kubectl]

  provisioner "local-exec" {
    command = "kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=true"
  }
}
