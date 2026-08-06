# --- data tier ------------------------------------------------------------
# external postgres and redis. a multi-node install requires both

# one security group for the whole data tier, both services live in the private
# subnets and are only reachable from inside the vpc regardless of these rules.
resource "aws_security_group" "ent_ha_data" {
  count  = var.enable_ent_ha ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ent_ha_data" {
  for_each = var.enable_ent_ha ? {
    postgres = 5432
    redis    = 6379
  } : {}

  security_group_id = aws_security_group.ent_ha_data[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}

resource "aws_db_subnet_group" "ent_ha_pg" {
  count       = var.enable_ent_ha ? 1 : 0
  name_prefix = "postgres-subnet-group"
  subnet_ids  = module.vpc.private_subnets
}

resource "aws_db_instance" "ent_ha_pg" {
  for_each               = toset(var.enable_ent_ha ? ["netbox", "diode", "hydra"] : [])
  engine                 = "postgres"
  instance_class         = "db.t4g.medium"
  username               = each.key
  password               = var.postgres_password
  db_name                = each.key
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.ent_ha_pg[0].name
  vpc_security_group_ids = [aws_security_group.ent_ha_data[0].id]
  skip_final_snapshot    = true
}

resource "aws_elasticache_subnet_group" "ent_ha_redis" {
  count      = var.enable_ent_ha ? 1 : 0
  name       = "ent-ha-redis-subnet-group-${data.external.whoami.result.username}"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_cluster" "ent_ha_redis" {
  count                = var.enable_ent_ha ? 1 : 0
  cluster_id           = "ent-ha-redis-${data.external.whoami.result.username}"
  engine               = "redis"
  node_type            = "cache.t4g.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.ent_ha_redis[0].name
  security_group_ids   = [aws_security_group.ent_ha_data[0].id]
}

# --- object storage -------------------------------------------------------
# netbox's file storage. also required for multi-node. netbox is configured with
# static credentials, and only an iam user can hold those, hence the user.

resource "aws_s3_bucket" "ent_ha_files" {
  count         = var.enable_ent_ha ? 1 : 0
  bucket_prefix = "ent-ha-files-"
  force_destroy = true
}

resource "aws_iam_user" "ent_ha_s3" {
  count = var.enable_ent_ha ? 1 : 0
  name  = "ent-ha-s3-user-${data.external.whoami.result.username}"
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

# --- node network ---------------------------------------------------------

resource "aws_security_group" "ent_ha_nodes" {
  count  = var.enable_ent_ha ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ent_ha_nodes_egress" {
  count             = var.enable_ent_ha ? 1 : 0
  security_group_id = aws_security_group.ent_ha_nodes[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# reachable from outside the vpc. 80 is both the nlb target port and how you hit
# a node directly, bypassing the load balancer, when troubleshooting ha.
resource "aws_vpc_security_group_ingress_rule" "ent_ha_public" {
  for_each = var.enable_ent_ha ? {
    https   = 443
    grpc    = 80
    console = 30000
  } : {}

  security_group_id = aws_security_group.ent_ha_nodes[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}

# every port the nodes need between themselves. deliberately explicit to validate docs.
resource "aws_vpc_security_group_ingress_rule" "ent_ha_cluster" {
  for_each = var.enable_ent_ha ? {
    apiserver = { from = 6443, to = 6443, proto = "tcp" }
    k0s       = { from = 9443, to = 9443, proto = "tcp" }
    etcd      = { from = 2379, to = 2380, proto = "tcp" }
    kubelet   = { from = 10250, to = 10250, proto = "tcp" }
    vxlan     = { from = 4789, to = 4789, proto = "udp" }
    bgp       = { from = 179, to = 179, proto = "tcp" }
  } : {}

  security_group_id            = aws_security_group.ent_ha_nodes[0].id
  referenced_security_group_id = aws_security_group.ent_ha_nodes[0].id
  from_port                    = each.value.from
  to_port                      = each.value.to
  ip_protocol                  = each.value.proto
}

# --- nodes ----------------------------------------------------------------
# node1 installs and publishes join commands to s3. node2 and node3 wait on the
# previous node's marker file, join, then publish their own.

resource "aws_instance" "ent_ha_node1" {
  count                  = var.enable_ent_ha ? 1 : 0
  ami                    = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type          = "m7i.2xlarge"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ent_ha_nodes[0].id]
  user_data = templatefile("${path.module}/ent-ha.sh.tpl", {
    enterprise_license_id       = var.enterprise_license_id,
    enterprise_console_password = var.enterprise_console_password,
    config_yaml = templatefile("${path.module}/ent-ha-config.yaml.tpl", {
      admin_password = var.enterprise_admin_password,
      pg_password    = var.postgres_password,
      netbox_pg_host = aws_db_instance.ent_ha_pg["netbox"].address,
      diode_pg_host  = aws_db_instance.ent_ha_pg["diode"].address,
      hydra_pg_host  = aws_db_instance.ent_ha_pg["hydra"].address,
      redis_host     = aws_elasticache_cluster.ent_ha_redis[0].cache_nodes[0].address,
      s3_bucket_name = aws_s3_bucket.ent_ha_files[0].id,
      s3_key_id      = aws_iam_access_key.ent_ha_s3[0].id,
      s3_access_key  = aws_iam_access_key.ent_ha_s3[0].secret,
      aws_region     = aws_s3_bucket.ent_ha_files[0].region
    })
    bucket = aws_s3_bucket.files.id
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = 6000
    throughput  = 250
  }

  tags = {
    Name = "ent_ha_node1"
  }
}

resource "aws_instance" "ent_ha_node" {
  for_each = var.enable_ent_ha ? {
    node2 = { wait_for = "node1.done" }
    node3 = { wait_for = "node2.done" }
  } : {}

  ami                         = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type               = "m7i.2xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ent_ha_nodes[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  user_data = templatefile("${path.module}/ent-ha-join.sh.tpl", {
    bucket   = aws_s3_bucket.files.id
    node     = each.key
    wait_for = each.value.wait_for
  })

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = 6000
    throughput  = 250
  }

  tags = {
    Name = "ent_ha_${each.key}"
  }
}

# --- load balancer --------------------------------------------------------
resource "aws_lb" "ent_ha" {
  count              = var.enable_ent_ha ? 1 : 0
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "ent_ha" {
  count    = var.enable_ent_ha ? 1 : 0
  port     = 80
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  stickiness {
    type    = "source_ip"
    enabled = true
  }

  health_check {
    protocol            = "HTTP"
    path                = "/login/"
    matcher             = "200"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "ent_ha_node1" {
  count            = var.enable_ent_ha ? 1 : 0
  target_group_arn = aws_lb_target_group.ent_ha[0].arn
  target_id        = aws_instance.ent_ha_node1[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ent_ha_node" {
  for_each         = aws_instance.ent_ha_node
  target_group_arn = aws_lb_target_group.ent_ha[0].arn
  target_id        = each.value.id
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

# --- outputs --------------------------------------------------------------

output "ent_ha_nlb_url" {
  value = var.enable_ent_ha ? "http://${aws_lb.ent_ha[0].dns_name}" : null
}

output "ent_ha_node1_ssm_command" {
  value = var.enable_ent_ha ? "aws ssm start-session --target ${aws_instance.ent_ha_node1[0].id}" : null
}

output "ent_ha_node2_ssm_command" {
  value = var.enable_ent_ha ? "aws ssm start-session --target ${aws_instance.ent_ha_node["node2"].id}" : null
}

output "ent_ha_node3_ssm_command" {
  value = var.enable_ent_ha ? "aws ssm start-session --target ${aws_instance.ent_ha_node["node3"].id}" : null
}

output "ent_ha_node1_console_url" {
  value = var.enable_ent_ha ? "https://${aws_instance.ent_ha_node1[0].public_ip}:30000" : null
}

output "ent_ha_node2_console_url" {
  value = var.enable_ent_ha ? "https://${aws_instance.ent_ha_node["node2"].public_ip}:30000" : null
}

output "ent_ha_node3_console_url" {
  value = var.enable_ent_ha ? "https://${aws_instance.ent_ha_node["node3"].public_ip}:30000" : null
}
