# second vm -- installer staged with the backup target baked in, restore run by hand
resource "aws_instance" "enterprise_dr_instance" {
  count                  = var.enable_enterprise && var.enable_enterprise_dr ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.enterprise_lab[0].id]
  user_data = templatefile("${path.module}/enterprise-dr.sh.tpl", {
    enterprise_license_id = var.enterprise_license_id
    bucket                = aws_s3_bucket.files.id
    region                = data.aws_region.current.region
    access_key_id         = aws_iam_access_key.backup[0].id
    secret_access_key     = aws_iam_access_key.backup[0].secret
  })
  user_data_replace_on_change = true
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "enterprise-dr"
  }
}

output "enterprise_dr_ssm_command" {
  value = var.enable_enterprise && var.enable_enterprise_dr ? "aws ssm start-session --target ${aws_instance.enterprise_dr_instance[0].id}" : null
}

output "enterprise_dr_webui_url" {
  value = var.enable_enterprise && var.enable_enterprise_dr ? "https://${aws_instance.enterprise_dr_instance[0].public_ip}" : null
}
