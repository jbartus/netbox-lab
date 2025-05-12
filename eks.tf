module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = "lab-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    spot = {
      min_size      = 1
      max_size      = 6
      desired_size  = 2
      instance_type = ["t4g.large"]
      capacity_type = "SPOT"
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }
}

resource "null_resource" "kubectl" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws --region us-east-1 eks update-kubeconfig --name ${module.eks.cluster_name}"
  }
}

resource "null_resource" "annotate_storageclass" {
  depends_on = [null_resource.kubectl]
  provisioner "local-exec" {
    command = "kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=true"
  }
}