resource "aws_security_group" "orb" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "orb_allow_all_out" {
  security_group_id = aws_security_group.orb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "orb_instance" {
  ami                    = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type          = "t4g.large"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.orb.id]
  user_data = templatefile("${path.module}/orb.sh.tpl", {
    orb_yaml = templatefile("${path.module}/orb.yaml.tpl", {
      diode_server  = aws_instance.nbe_instance.private_ip,
      public_subnet = module.vpc.public_subnet_objects[0].cidr_block
    })
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
}

output "orb_ssm_command" {
  value = "aws ssm start-session --target ${aws_instance.orb_instance.id}"
}
