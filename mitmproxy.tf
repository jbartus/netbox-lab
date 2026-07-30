locals {
  mitmproxy_proxy_url = var.enable_mitmproxy ? "http://testuser:passw0rd@${aws_instance.mitmproxy_instance[0].private_ip}:8080" : ""
  mitmproxy_ca_cert   = var.enable_mitmproxy ? tls_self_signed_cert.mitmproxy_ca[0].cert_pem : ""
}

resource "aws_security_group" "mitmproxy" {
  count  = var.enable_mitmproxy ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "mitmproxy_allow_all_out" {
  count             = var.enable_mitmproxy ? 1 : 0
  security_group_id = aws_security_group.mitmproxy[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "mitmproxy_allow_proxy_in" {
  count             = var.enable_mitmproxy ? 1 : 0
  security_group_id = aws_security_group.mitmproxy[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_instance" "mitmproxy_instance" {
  count                  = var.enable_mitmproxy ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type          = "m8g.xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.mitmproxy[0].id]
  user_data = templatefile("${path.module}/mitmproxy.sh", {
    # mitmproxy wants key + cert concatenated in one mitmproxy-ca.pem
    ca_pem = var.enable_mitmproxy ? "${tls_private_key.mitmproxy_ca[0].private_key_pem}${tls_self_signed_cert.mitmproxy_ca[0].cert_pem}" : ""
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "mitmproxy"
  }
}

output "mitmproxy_ssm_command" {
  value = var.enable_mitmproxy ? "aws ssm start-session --target ${aws_instance.mitmproxy_instance[0].id}" : null
}
