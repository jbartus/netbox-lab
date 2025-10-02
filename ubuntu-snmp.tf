resource "aws_security_group" "ubuntu" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ubuntu_allow_all_out" {
  security_group_id = aws_security_group.ubuntu.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ubuntu_allow_snmp_in" {
  security_group_id = aws_security_group.ubuntu.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 161
  to_port           = 161
  ip_protocol       = "udp"
}

resource "aws_instance" "ubuntu_instance" {
  ami                         = data.aws_ssm_parameter.ubuntu_2404_ami_amd64.value
  instance_type               = "m7i.xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ubuntu.id]
  user_data                   = file("${path.module}/ubuntu.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "ubuntu"
  }
}

output "ubuntu_ssm_command" {
  value = "aws ssm start-session --target ${aws_instance.ubuntu_instance.id}"
}
