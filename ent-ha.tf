resource "aws_db_subnet_group" "ent_ha_pg" {
  count       = var.enable_ent_ha ? 1 : 0
  name_prefix = "postgres-subnet-group"
  subnet_ids  = module.vpc.private_subnets
}

resource "aws_security_group" "ent_ha_pg" {
  count  = var.enable_ent_ha ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_pg_allow_psql_in" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_pg[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_db_instance" "netbox" {
  count                  = var.enable_ent_ha ? 1 : 0
  engine                 = "postgres"
  instance_class         = "db.t4g.medium"
  username               = "netbox"
  password               = var.postgres_password
  db_name                = "netbox"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.ent_ha_pg[0].name
  vpc_security_group_ids = [aws_security_group.ent_ha_pg[0].id]
  skip_final_snapshot    = true
}

resource "aws_db_instance" "diode" {
  count                  = var.enable_ent_ha ? 1 : 0
  engine                 = "postgres"
  instance_class         = "db.t4g.medium"
  username               = "diode"
  password               = var.postgres_password
  db_name                = "diode"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.ent_ha_pg[0].name
  vpc_security_group_ids = [aws_security_group.ent_ha_pg[0].id]
  skip_final_snapshot    = true
}

resource "aws_db_instance" "hydra" {
  count                  = var.enable_ent_ha ? 1 : 0
  engine                 = "postgres"
  instance_class         = "db.t4g.medium"
  username               = "hydra"
  password               = var.postgres_password
  db_name                = "hydra"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.ent_ha_pg[0].name
  vpc_security_group_ids = [aws_security_group.ent_ha_pg[0].id]
  skip_final_snapshot    = true
}

resource "aws_security_group" "ent_ha_lab" {
  count  = var.enable_ent_ha ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ent_ha_allow_all_out" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_https_in" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_grpc_in" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_console_in" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_lab[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 30000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_apiserver_in" {
  count                        = var.enable_ent_ha ? 1 : 0
  security_group_id            = aws_security_group.ent_ha_lab[0].id
  referenced_security_group_id = aws_security_group.ent_ha_lab[0].id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_k0s_in" {
  count                        = var.enable_ent_ha ? 1 : 0
  security_group_id            = aws_security_group.ent_ha_lab[0].id
  referenced_security_group_id = aws_security_group.ent_ha_lab[0].id
  from_port                    = 9443
  to_port                      = 9443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_etcd_in" {
  count                        = var.enable_ent_ha ? 1 : 0
  security_group_id            = aws_security_group.ent_ha_lab[0].id
  referenced_security_group_id = aws_security_group.ent_ha_lab[0].id
  from_port                    = 2379
  to_port                      = 2380
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_kubelet_in" {
  count                        = var.enable_ent_ha ? 1 : 0
  security_group_id            = aws_security_group.ent_ha_lab[0].id
  referenced_security_group_id = aws_security_group.ent_ha_lab[0].id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_vxlan_in" {
  count                        = var.enable_ent_ha ? 1 : 0
  security_group_id            = aws_security_group.ent_ha_lab[0].id
  referenced_security_group_id = aws_security_group.ent_ha_lab[0].id
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_allow_bgp_in" {
  count                        = var.enable_ent_ha ? 1 : 0
  security_group_id            = aws_security_group.ent_ha_lab[0].id
  referenced_security_group_id = aws_security_group.ent_ha_lab[0].id
  from_port                    = 179
  to_port                      = 179
  ip_protocol                  = "tcp"
}

resource "aws_instance" "ent_ha_node1" {
  count                  = var.enable_ent_ha ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ent_ha_lab[0].id]
  user_data = templatefile("${path.module}/ent-ha.sh.tpl", {
    enterprise_license_id       = var.enterprise_license_id,
    enterprise_console_password = var.enterprise_console_password,
    enterprise_release_channel  = var.enterprise_release_channel,
    config_yaml = templatefile("${path.module}/ent-ha-config.yaml.tpl", {
      admin_password = var.enterprise_admin_password,
      pg_password    = var.postgres_password,
      netbox_pg_host = aws_db_instance.netbox[0].address,
      diode_pg_host  = aws_db_instance.diode[0].address,
      hydra_pg_host  = aws_db_instance.hydra[0].address,
      s3_bucket_name = aws_s3_bucket.ent_ha_files[0].id,
      s3_key_id      = aws_iam_access_key.ent_ha_s3[0].id,
      s3_access_key  = aws_iam_access_key.ent_ha_s3[0].secret,
      aws_region     = aws_s3_bucket.ent_ha_files[0].region
    })
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "ent_ha_node1"
  }
}

resource "aws_instance" "ent_ha_node2" {
  count                       = var.enable_ent_ha ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type               = "m7i.2xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ent_ha_lab[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "ent_ha_node2"
  }
}

resource "aws_instance" "ent_ha_node3" {
  count                       = var.enable_ent_ha ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type               = "m7i.2xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ent_ha_lab[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "ent_ha_node3"
  }
}

resource "aws_s3_bucket" "ent_ha_files" {
  count         = var.enable_ent_ha ? 1 : 0
  bucket_prefix = "ent-ha-files-"
  force_destroy = true
}

resource "aws_iam_user" "ent_ha_s3" {
  count = var.enable_ent_ha ? 1 : 0
  name  = "ent-ha-s3-user"
}

resource "aws_iam_user_policy" "ent_ha_s3_rw" {
  count = var.enable_ent_ha ? 1 : 0
  user  = aws_iam_user.ent_ha_s3[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.ent_ha_files[0].arn, "${aws_s3_bucket.ent_ha_files[0].arn}/*"]
    }]
  })
}

resource "aws_iam_access_key" "ent_ha_s3" {
  count = var.enable_ent_ha ? 1 : 0
  user  = aws_iam_user.ent_ha_s3[0].name
}

resource "aws_security_group" "ent_ha_nlb" {
  count  = var.enable_ent_ha ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ent_ha_nlb_allow_all_out" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_nlb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_nlb_allow_http_in" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_nlb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_lb" "ent_ha" {
  count              = var.enable_ent_ha ? 1 : 0
  name               = "ent-ha-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ent_ha_nlb[0].id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "ent_ha" {
  count    = var.enable_ent_ha ? 1 : 0
  name     = "ent-ha-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  stickiness {
    type    = "source_ip"
    enabled = true
  }

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_target_group_attachment" "ent_ha_node1" {
  count            = var.enable_ent_ha ? 1 : 0
  target_group_arn = aws_lb_target_group.ent_ha[0].arn
  target_id        = aws_instance.ent_ha_node1[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ent_ha_node2" {
  count            = var.enable_ent_ha ? 1 : 0
  target_group_arn = aws_lb_target_group.ent_ha[0].arn
  target_id        = aws_instance.ent_ha_node2[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ent_ha_node3" {
  count            = var.enable_ent_ha ? 1 : 0
  target_group_arn = aws_lb_target_group.ent_ha[0].arn
  target_id        = aws_instance.ent_ha_node3[0].id
  port             = 80
}

resource "aws_lb_listener" "ent_ha_http" {
  count             = var.enable_ent_ha ? 1 : 0
  load_balancer_arn = aws_lb.ent_ha[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ent_ha[0].arn
  }
}

output "ent_ha_nlb_url" {
  value = var.enable_ent_ha ? "http://${aws_lb.ent_ha[0].dns_name}" : null
}

output "ent_ha_node1_ssm_command" {
  value = var.enable_ent_ha ? "aws ssm start-session --target ${aws_instance.ent_ha_node1[0].id}" : null
}

output "ent_ha_node2_ssm_command" {
  value = var.enable_ent_ha ? "aws ssm start-session --target ${aws_instance.ent_ha_node2[0].id}" : null
}

output "ent_ha_node3_ssm_command" {
  value = var.enable_ent_ha ? "aws ssm start-session --target ${aws_instance.ent_ha_node3[0].id}" : null
}

output "ent_ha_node1_console_url" {
  value = var.enable_ent_ha ? "https://${aws_instance.ent_ha_node1[0].public_ip}:30000" : null
}

output "ent_ha_node1_webui_url" {
  value = var.enable_ent_ha ? "https://${aws_instance.ent_ha_node1[0].public_ip}" : null
}
