resource "aws_security_group" "enterprise_lab" {
  count  = var.enable_enterprise ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

# allow outbound by default, but not if mitmproxy is enabled
resource "aws_vpc_security_group_egress_rule" "enterprise_allow_all_out" {
  count             = var.enable_enterprise && !var.enable_mitmproxy ? 1 : 0
  security_group_id = aws_security_group.enterprise_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# allow communication with the proxy and vpc endpoints for ssm & dns
resource "aws_vpc_security_group_egress_rule" "enterprise_allow_vpc_out" {
  count             = var.enable_enterprise && var.enable_mitmproxy ? 1 : 0
  security_group_id = aws_security_group.enterprise_lab[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "enterprise_allow_https_in" {
  count             = var.enable_enterprise ? 1 : 0
  security_group_id = aws_security_group.enterprise_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "enterprise_allow_grpc_in" {
  count             = var.enable_enterprise ? 1 : 0
  security_group_id = aws_security_group.enterprise_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "enterprise_allow_30k_in" {
  count             = var.enable_enterprise ? 1 : 0
  security_group_id = aws_security_group.enterprise_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 30000
  ip_protocol       = "tcp"
}

resource "aws_instance" "enterprise_instance" {
  count                  = var.enable_enterprise ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.enterprise_lab[0].id]
  user_data = templatefile("${path.module}/enterprise.sh.tpl", {
    enterprise_license_id       = var.enterprise_license_id,
    enterprise_console_password = var.enterprise_console_password,
    enterprise_release_channel  = var.enterprise_release_channel,
    config_yaml = templatefile("${path.module}/enterprise-config.yaml.tpl", {
      enterprise_admin_password = var.enterprise_admin_password
      ca_cert_pem               = local.mitmproxy_ca_cert
      # interim workaround for the empty-lowercase-proxy-env bug
      proxy_url = local.mitmproxy_proxy_url
    })
    enterprise_wh_sh    = file("${path.module}/enterprise-wheelhouse.sh")
    clear_deviations_sh = file("${path.module}/clear-deviations.sh")
    proxy_url           = local.mitmproxy_proxy_url
    ca_cert_pem         = local.mitmproxy_ca_cert
    bucket              = aws_s3_bucket.files.id
    enable_discovery    = var.enable_discovery
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "enterprise"
  }
}

output "enterprise_ssm_command" {
  value = var.enable_enterprise ? "aws ssm start-session --target ${aws_instance.enterprise_instance[0].id}" : null
}

output "enterprise_console_url" {
  value = var.enable_enterprise ? "https://${aws_instance.enterprise_instance[0].public_ip}:30000" : null
}

output "enterprise_webui_url" {
  value = var.enable_enterprise ? "https://${aws_instance.enterprise_instance[0].public_ip}" : null
}
