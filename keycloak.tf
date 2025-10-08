resource "aws_security_group" "keycloak" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "keycloak_allow_all_out" {
  security_group_id = aws_security_group.keycloak.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "keycloak_allow_https_in" {
  security_group_id = aws_security_group.keycloak.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_instance" "keycloak_instance" {
  ami                         = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type               = "m8g.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.keycloak.id]
  user_data                   = file("${path.module}/keycloak.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "keycloak"
  }
}

output "keycloak_ssm_command" {
  value = "aws ssm start-session --target ${aws_instance.keycloak_instance.id}"
}

output "keycloak_url" {
  value = "https://${aws_instance.keycloak_instance.public_ip}/admin"
}