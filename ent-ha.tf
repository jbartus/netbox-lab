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

# reachable from outside the vpc. 443 is both the nlb target port and how you hit
# a node directly, bypassing the load balancer, when troubleshooting ha. 80 only
# redirects to 443.
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
      admin_password = var.enterprise_admin_password
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
  port     = 443
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  stickiness {
    type    = "source_ip"
    enabled = true
  }

  # nlb https health checks don't validate certs, so nbe's self-signed one is fine
  health_check {
    protocol            = "HTTPS"
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
  port             = 443
}

resource "aws_lb_target_group_attachment" "ent_ha_node" {
  for_each         = aws_instance.ent_ha_node
  target_group_arn = aws_lb_target_group.ent_ha[0].arn
  target_id        = each.value.id
  port             = 443
}

resource "aws_lb_listener" "ent_ha_https" {
  count             = var.enable_ent_ha ? 1 : 0
  load_balancer_arn = aws_lb.ent_ha[0].arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ent_ha[0].arn
  }
}

# --- outputs --------------------------------------------------------------

output "ent_ha_nlb_url" {
  value = var.enable_ent_ha ? "https://${aws_lb.ent_ha[0].dns_name}" : null
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
