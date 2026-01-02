resource "aws_security_group" "ubuntu" {
  count  = var.enable_ubuntu ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ubuntu_allow_all_out" {
  count             = var.enable_ubuntu ? 1 : 0
  security_group_id = aws_security_group.ubuntu[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "ubuntu_instance" {
  count                       = var.enable_ubuntu ? 1 : 0
  ami                         = data.aws_ssm_parameter.ubuntu_2404_ami_amd64.value
  instance_type               = "m7i.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ubuntu[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "ubuntu"
  }
}

output "ubuntu_ssm_command" {
  value = var.enable_ubuntu ? "aws ssm start-session --target ${aws_instance.ubuntu_instance[0].id}" : null
}
