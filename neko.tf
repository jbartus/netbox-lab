resource "aws_security_group" "neko_lab" {
  count  = var.enable_neko ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "neko_allow_all_out" {
  count             = var.enable_neko ? 1 : 0
  security_group_id = aws_security_group.neko_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "neko_allow_https_in" {
  count             = var.enable_neko ? 1 : 0
  security_group_id = aws_security_group.neko_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "neko_allow_grpc_in" {
  count             = var.enable_neko ? 1 : 0
  security_group_id = aws_security_group.neko_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "neko_allow_30k_in" {
  count             = var.enable_neko ? 1 : 0
  security_group_id = aws_security_group.neko_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 30000
  ip_protocol       = "tcp"
}

resource "aws_instance" "neko_instance" {
  count                  = var.enable_neko ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.neko_lab[0].id]
  user_data = templatefile("${path.module}/neko.sh.tpl", {
    neko_license_id       = var.neko_license_id,
    neko_console_password = var.neko_console_password,
    config_yaml = templatefile("${path.module}/neko-config.yaml.tpl", {
      neko_admin_password = var.neko_admin_password
    })
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "neko"
  }
}

output "neko_ssm_command" {
  value = var.enable_neko ? "aws ssm start-session --target ${aws_instance.neko_instance[0].id}" : null
}

output "neko_console_url" {
  value = var.enable_neko ? "https://${aws_instance.neko_instance[0].public_ip}:30000" : null
}

output "neko_webui_url" {
  value = var.enable_neko ? "https://${aws_instance.neko_instance[0].public_ip}:8443" : null
}
