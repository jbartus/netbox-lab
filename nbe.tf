resource "aws_security_group" "nbe_lab" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "nbe_allow_all_out" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "nbe_allow_https_in" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nbe_allow_grpc_in" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nbe_allow_30k_in" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 30000
  ip_protocol       = "tcp"
}

resource "aws_instance" "nbe_instance" {
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.nbe_lab.id]
  user_data = templatefile("${path.module}/nbe.sh.tpl", {
    nbe_token            = var.nbe_token,
    nbe_console_password = var.nbe_console_password,
    config_yaml = templatefile("${path.module}/config.yaml.tpl", {
      nbe_admin_password = var.nbe_admin_password
    })
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }
}

output "nbe_ssm_command" {
  value = "aws --region us-east-1 ssm start-session --target ${aws_instance.nbe_instance.id}"
}

output "nbe_console_url" {
  value = "https://${aws_instance.nbe_instance.public_ip}:30000"
}

output "nbe_webui_url" {
  value = "https://${aws_instance.nbe_instance.public_ip}"
}
