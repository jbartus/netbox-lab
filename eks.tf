module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  name               = "lab-cluster"
  kubernetes_version = "1.33"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns    = {}
    kube-proxy = {}
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
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }
}

resource "null_resource" "kubectl" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name}"
  }
}

resource "null_resource" "annotate_storageclass" {
  depends_on = [null_resource.kubectl]
  provisioner "local-exec" {
    command = "kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=true"
  }
}
