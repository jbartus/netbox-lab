resource "aws_security_group" "c8kv" {
  count  = var.enable_discovery ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "c8kv_allow_all_out" {
  count             = var.enable_discovery ? 1 : 0
  security_group_id = aws_security_group.c8kv[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "c8kv_allow_ssh_in" {
  count             = var.enable_discovery ? 1 : 0
  security_group_id = aws_security_group.c8kv[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "c8kv_allow_snmp_in" {
  count             = var.enable_discovery ? 1 : 0
  security_group_id = aws_security_group.c8kv[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 161
  to_port           = 161
  ip_protocol       = "udp"
}

data "aws_ssm_parameter" "c8kv_byol" {
  count = var.enable_discovery ? 1 : 0
  name  = "/aws/service/marketplace/prod-rhyp4n745z2jk/latest"
}

resource "aws_instance" "c8kv_instance" {
  count                       = var.enable_discovery ? 1 : 0
  ami                         = data.aws_ssm_parameter.c8kv_byol[0].value
  instance_type               = "c5n.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.c8kv[0].id]
  associate_public_ip_address = true
  user_data                   = "Section: IOS configuration\nusername iosuser privilege 15 secret hardcode\nsnmp-server community public ro"

  tags = {
    Name = "c8kv"
  }
}
