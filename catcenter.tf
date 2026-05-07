resource "aws_security_group" "catcenter" {
  count  = var.enable_catcenter ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "catcenter_allow_all_out" {
  count             = var.enable_catcenter ? 1 : 0
  security_group_id = aws_security_group.catcenter[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "catcenter_allow_ssh_in" {
  count             = var.enable_catcenter ? 1 : 0
  security_group_id = aws_security_group.catcenter[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 2222
  to_port           = 2222
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "catcenter_allow_https_in" {
  count             = var.enable_catcenter ? 1 : 0
  security_group_id = aws_security_group.catcenter[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "catcenter_allow_http_in" {
  count             = var.enable_catcenter ? 1 : 0
  security_group_id = aws_security_group.catcenter[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

data "aws_ami" "catcenter" {
  count       = var.enable_catcenter ? 1 : 0
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "product-code"
    values = ["23mo3cs0gtaytd32egz7zwpgc"]
  }
}

resource "tls_private_key" "catcenter" {
  count     = var.enable_catcenter ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "catcenter" {
  count      = var.enable_catcenter ? 1 : 0
  key_name   = "catcenter-temp"
  public_key = tls_private_key.catcenter[0].public_key_openssh
}

resource "local_file" "catcenter_key" {
  count           = var.enable_catcenter ? 1 : 0
  content         = tls_private_key.catcenter[0].private_key_pem
  filename        = "${path.module}/catcenter-temp.pem"
  file_permission = "0400"
}

locals {
  catcenter_userdata = <<-EOF
  #cloud-config
  write_files:
    - path: /etc/cloud.json
      encoding: b64
      content: ${base64encode(jsonencode({
  IPaddress   = "10.0.1.100"
  netmask     = "255.255.255.0"
  gateway     = "10.0.1.1"
  dns_servers = ["8.8.8.8"]
  ntp         = ["0.pool.ntp.org", "1.pool.ntp.org"]
  password    = var.catcenter_ssh_password
  fqdn        = "catcenter.lab.local"
}))}
      permissions: '0644'
  EOF
}

resource "aws_launch_template" "catcenter" {
  count = var.enable_catcenter ? 1 : 0
  name  = "catcenter"

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdg"
    ebs {
      delete_on_termination = true
    }
  }
}

resource "aws_instance" "catcenter_instance" {
  count                       = var.enable_catcenter ? 1 : 0
  ami                         = data.aws_ami.catcenter[0].id
  instance_type               = "r5a.8xlarge"
  key_name                    = aws_key_pair.catcenter[0].key_name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.catcenter[0].id]
  associate_public_ip_address = true
  private_ip                  = "10.0.1.100"
  user_data                   = local.catcenter_userdata

  launch_template {
    id = aws_launch_template.catcenter[0].id
  }

  tags = {
    Name = "catcenter"
  }
}

output "catcenter_public_ip" {
  value = var.enable_catcenter ? aws_instance.catcenter_instance[0].public_ip : null
}

output "catcenter_ssh" {
  value = var.enable_catcenter ? "ssh -i catcenter-temp.pem maglev@${aws_instance.catcenter_instance[0].public_ip} -p 2222" : null
}

output "catcenter_gui" {
  value = var.enable_catcenter ? "https://${aws_instance.catcenter_instance[0].public_ip} (admin / P@ssword9 — change on first login)" : null
}
