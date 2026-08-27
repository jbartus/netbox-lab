resource "aws_security_group" "clab" {
  count  = var.enable_clab ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "clab_allow_all_out" {
  count             = var.enable_clab ? 1 : 0
  security_group_id = aws_security_group.clab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# clab node traffic arrives on this ENI, so it needs an inbound rule
resource "aws_vpc_security_group_ingress_rule" "clab_allow_vpc_in" {
  count             = var.enable_clab ? 1 : 0
  security_group_id = aws_security_group.clab[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "-1"
}

# terraform owns the upload so the object exists before user_data wants it
resource "aws_s3_object" "clab_images" {
  for_each = var.enable_clab ? fileset("${path.module}/clab-images", "*") : []
  bucket   = aws_s3_bucket.files.id
  key      = "clab-images/${each.value}"
  source   = "${path.module}/clab-images/${each.value}"
}

resource "aws_instance" "clab_instance" {
  count                  = var.enable_clab ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.clab[0].id]
  user_data = templatefile("${path.module}/clab.sh.tpl", {
    bucket    = aws_s3_bucket.files.id
    topo_yaml = file("${path.module}/clab-topo.yml")
    spine_cfg = file("${path.module}/clab-spine.cfg")
    leaf_cfg  = file("${path.module}/clab-leaf.cfg")
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  # required to forward for the clab mgmt subnet
  source_dest_check = false
  # the whole lab lives in user_data, so edits have to rebuild the vm
  user_data_replace_on_change = true

  depends_on = [aws_s3_object.clab_images]

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "clab"
  }
}

# containerlab opens DOCKER-USER itself, so only the vpc side needs wiring
resource "aws_route" "clab_mgmt" {
  count                  = var.enable_clab ? 1 : 0
  route_table_id         = module.vpc.public_route_table_ids[0]
  destination_cidr_block = "172.20.20.0/24"
  network_interface_id   = aws_instance.clab_instance[0].primary_network_interface_id
}

output "clab_ssm_command" {
  value = var.enable_clab ? "aws ssm start-session --target ${aws_instance.clab_instance[0].id}" : null
}
