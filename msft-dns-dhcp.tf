resource "aws_security_group" "msft_dns_dhcp" {
  count       = var.enable_msft_dns_dhcp ? 1 : 0
  vpc_id      = module.vpc.vpc_id
  name        = "msft-dns-dhcp"
  description = "WinRM access for the Windows DNS + DHCP data source box"
}

resource "aws_vpc_security_group_ingress_rule" "msft_dns_dhcp_allow_winrm_http_in" {
  count             = var.enable_msft_dns_dhcp ? 1 : 0
  security_group_id = aws_security_group.msft_dns_dhcp[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5985
  to_port           = 5985
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "msft_dns_dhcp_allow_winrm_https_in" {
  count             = var.enable_msft_dns_dhcp ? 1 : 0
  security_group_id = aws_security_group.msft_dns_dhcp[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5986
  to_port           = 5986
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "msft_dns_dhcp_allow_all_out" {
  count             = var.enable_msft_dns_dhcp ? 1 : 0
  security_group_id = aws_security_group.msft_dns_dhcp[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "msft_dns_dhcp_instance" {
  count                       = var.enable_msft_dns_dhcp ? 1 : 0
  ami                         = data.aws_ssm_parameter.windows_server_2022_ami_x86_64.value
  instance_type               = "t3.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.msft_dns_dhcp[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  user_data                   = file("${path.module}/msft-dns-dhcp.ps1")

  tags = {
    Name = "msft-dns-dhcp"
  }
}

output "msft_dns_dhcp_ssm_command" {
  value = var.enable_msft_dns_dhcp ? "aws ssm start-session --target ${aws_instance.msft_dns_dhcp_instance[0].id}" : null
}
