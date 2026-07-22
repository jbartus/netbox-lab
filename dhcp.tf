resource "aws_security_group" "dhcp" {
  count  = var.enable_dhcp ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "dhcp_allow_winrm_http_in" {
  count             = var.enable_dhcp ? 1 : 0
  security_group_id = aws_security_group.dhcp[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5985
  to_port           = 5985
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "dhcp_allow_winrm_https_in" {
  count             = var.enable_dhcp ? 1 : 0
  security_group_id = aws_security_group.dhcp[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5986
  to_port           = 5986
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "dhcp_allow_all_out" {
  count             = var.enable_dhcp ? 1 : 0
  security_group_id = aws_security_group.dhcp[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "dhcp_instance" {
  count                       = var.enable_dhcp ? 1 : 0
  ami                         = data.aws_ssm_parameter.windows_server_2022_ami_x86_64.value
  instance_type               = "t3.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.dhcp[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  user_data                   = file("${path.module}/dhcp.ps1")

  tags = {
    Name = "dhcp"
  }
}

output "dhcp_private_ip" {
  value = var.enable_dhcp ? aws_instance.dhcp_instance[0].private_ip : null
}

output "dhcp_winrm" {
  value = var.enable_dhcp ? "winrm://${aws_instance.dhcp_instance[0].private_ip}:5985" : null
}

output "dhcp_service_account" {
  value = var.enable_dhcp ? ".\\svc-netbox" : null
}

output "dhcp_service_password" {
  value = var.enable_dhcp ? "NetBoxDHCP123!" : null
}

output "dhcp_ssm_command" {
  value = var.enable_dhcp ? "aws ssm start-session --target ${aws_instance.dhcp_instance[0].id}" : null
}
