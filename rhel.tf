resource "aws_security_group" "rhel" {
  count  = var.enable_rhel ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "rhel_allow_all_out" {
  count             = var.enable_rhel ? 1 : 0
  security_group_id = aws_security_group.rhel[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "rhel_instance" {
  count                       = var.enable_rhel ? 1 : 0
  ami                         = data.aws_ami.rhel_97_ami_x86_64.id
  instance_type               = "m7i.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.rhel[0].id]
  user_data                   = file("${path.module}/rhel.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "rhel"
  }
}

output "rhel_ssm_command" {
  value = var.enable_rhel ? "aws ssm start-session --target ${aws_instance.rhel_instance[0].id}" : null
}
