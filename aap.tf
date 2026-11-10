locals {
  aap_installer = "ansible-automation-platform-containerized-setup-2.7-12"
}

resource "aws_security_group" "aap" {
  count  = var.enable_aap ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "aap_allow_all_out" {
  count             = var.enable_aap ? 1 : 0
  security_group_id = aws_security_group.aap[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "aap_allow_https_in" {
  count             = var.enable_aap ? 1 : 0
  security_group_id = aws_security_group.aap[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "aap_allow_webhook_in" {
  count             = var.enable_aap ? 1 : 0
  security_group_id = aws_security_group.aap[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 5000
  to_port           = 5000
  ip_protocol       = "tcp"
}

resource "aws_s3_object" "aap_installer" {
  count  = var.enable_aap ? 1 : 0
  bucket = aws_s3_bucket.files.id
  key    = "${local.aap_installer}.tar"
  source = "${path.module}/${local.aap_installer}.tar"
  etag   = filemd5("${path.module}/${local.aap_installer}.tar")
}

resource "aws_instance" "aap_instance" {
  count                  = var.enable_aap ? 1 : 0
  ami                    = data.aws_ami.rhel_102_ami_x86_64.id
  instance_type          = "m8i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.aap[0].id]
  user_data = templatefile("${path.module}/aap.sh.tpl", {
    bucket           = aws_s3_bucket.files.id
    installer        = local.aap_installer
    admin_password   = var.aap_admin_password
    registry_user    = var.rh_registry_user
    registry_token   = var.rh_registry_token
    rh_client_id     = var.rh_client_id
    rh_client_secret = var.rh_client_secret
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "aap"
  }

  depends_on = [aws_s3_object.aap_installer]
}

output "aap_ssm_command" {
  value = var.enable_aap ? "aws ssm start-session --target ${aws_instance.aap_instance[0].id}" : null
}

output "aap_url" {
  value = var.enable_aap ? "https://${aws_instance.aap_instance[0].public_ip}" : null
}
