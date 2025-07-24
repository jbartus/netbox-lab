resource "aws_security_group" "ansible" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ansible_allow_all_out" {
  security_group_id = aws_security_group.ansible.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "ansible_instance" {
  ami                    = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type          = "t4g.large"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ansible.id]
  user_data = templatefile("${path.module}/ansible.sh.tpl", {
    ansible_in_yaml = file("${path.module}/ansible-in.yaml"),
    netbox_api      = aws_instance.nbe_instance.private_ip
    admin_password  = var.nbe_admin_password
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
}

output "ansible_ssm_command" {
  value = "aws ssm start-session --target ${aws_instance.ansible_instance.id}"
}
