resource "aws_security_group" "docker" {
  count  = var.enable_docker ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "docker_allow_all_out" {
  count             = var.enable_docker ? 1 : 0
  security_group_id = aws_security_group.docker[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "docker_allow_http_in" {
  count             = var.enable_docker ? 1 : 0
  security_group_id = aws_security_group.docker[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8000
  to_port           = 8000
  ip_protocol       = "tcp"
}

resource "aws_instance" "docker_instance" {
  count                       = var.enable_docker ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type               = "m8g.xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.docker[0].id]
  user_data                   = file("${path.module}/docker.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "docker"
  }
}

output "docker_ssm_command" {
  value = var.enable_docker ? "aws ssm start-session --target ${aws_instance.docker_instance[0].id}" : null
}

output "docker_url" {
  value = var.enable_docker ? "http://${aws_instance.docker_instance[0].public_ip}:8000" : null
}