resource "aws_security_group" "orb" {
  count  = var.enable_discovery ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "orb_allow_all_out" {
  count             = var.enable_discovery ? 1 : 0
  security_group_id = aws_security_group.orb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "orb_instance" {
  count                  = var.enable_discovery ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type          = "t4g.large"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.orb[0].id]
  user_data = templatefile("${path.module}/orb.sh.tpl", {
    diode_server = var.enable_enterprise ? aws_instance.enterprise_instance[0].private_ip : "",
    orb_yaml = templatefile("${path.module}/orb.yaml.tpl", {
      public_subnet = module.vpc.public_subnet_objects[0].cidr_block
      c8kv_ip       = aws_instance.c8kv_instance[0].private_ip
    })
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "orb"
  }

}

output "orb_ssm_command" {
  value = var.enable_discovery ? "aws ssm start-session --target ${aws_instance.orb_instance[0].id}" : null
}
