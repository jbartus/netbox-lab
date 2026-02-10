resource "aws_security_group" "ansible" {
  count  = var.enable_ansible ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ansible_allow_all_out" {
  count             = var.enable_ansible ? 1 : 0
  security_group_id = aws_security_group.ansible[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ansible_allow_webhook_in" {
  count             = var.enable_ansible ? 1 : 0
  security_group_id = aws_security_group.ansible[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5000
  to_port           = 5000
  ip_protocol       = "tcp"
}

resource "aws_instance" "ansible_instance" {
  count                  = var.enable_ansible ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type          = "t4g.large"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ansible[0].id]
  user_data = templatefile("${path.module}/ansible.sh.tpl", {
    ansible_in_yaml = file("${path.module}/ansible-in.yaml")
    rulebook_yaml   = file("${path.module}/rulebook.yaml")
    int_desc_yaml   = file("${path.module}/int-desc.yaml")
    c8kv_ip         = aws_instance.c8kv_instance[0].private_ip
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "ansible"
  }

  lifecycle {
    precondition {
      condition     = var.enable_discovery
      error_message = "Ansible requires enable_discovery = true (for the c8kv target)."
    }
  }
}

output "ansible_ssm_command" {
  value = var.enable_ansible ? "aws ssm start-session --target ${aws_instance.ansible_instance[0].id}" : null
}
