resource "aws_security_group" "ad-ldap" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ad-ldap_allow_ldap_in" {
  security_group_id = aws_security_group.ad-ldap.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 389
  to_port           = 389
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ad-ldap_allow_all_out" {
  security_group_id = aws_security_group.ad-ldap.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "ad-ldap_instance" {
  ami                         = data.aws_ssm_parameter.windows_server_2022_ami_x86_64.value
  instance_type               = "m7i.xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ad-ldap.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  user_data                   = file("${path.module}/ad-ldap.ps1")

  tags = {
    Name = "ad-ldap"
  }
}
