resource "aws_security_group" "c8kv" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "c8kv_allow_all_out" {
  security_group_id = aws_security_group.c8kv.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "c8kv_allow_ssh_in" {
  security_group_id = aws_security_group.c8kv.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "c8kv_allow_snmp_in" {
  security_group_id = aws_security_group.c8kv.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 161
  to_port           = 161
  ip_protocol       = "udp"
}

data "aws_ami" "c8kv_byol" {
  owners = ["aws-marketplace"]
  filter {
    name   = "name"
    values = ["Cisco-C8K-*"]
  }
  filter {
    name   = "product-code"
    values = ["3ycwqehancx46bkpb3xkifiz5"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  most_recent = true
}

resource "aws_instance" "c8kv_instance" {
  ami                         = data.aws_ami.c8kv_byol.id
  instance_type               = "c5n.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.c8kv.id]
  associate_public_ip_address = true
  user_data                   = "Section: IOS configuration\nusername iosuser privilege 15 secret Hardcode12345\nsnmp-server community public ro"
}
