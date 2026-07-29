resource "aws_iam_role" "ssm_instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  role = aws_iam_role.ssm_instance_role.name
}

# vpc endpoints needed for ssm to work when mitmproxy is enabled
data "aws_region" "current" {}

resource "aws_security_group" "vpce" {
  count  = var.enable_mitmproxy ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https_in" {
  count             = var.enable_mitmproxy ? 1 : 0
  security_group_id = aws_security_group.vpce[0].id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_endpoint" "ssm" {
  count               = var.enable_mitmproxy ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.public_subnets
  security_group_ids  = [aws_security_group.vpce[0].id]
  private_dns_enabled = true # VPC-wide: default AWS hostnames resolve to the endpoint

  tags = { Name = "vpce-ssm" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.enable_mitmproxy ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.public_subnets
  security_group_ids  = [aws_security_group.vpce[0].id]
  private_dns_enabled = true

  tags = { Name = "vpce-ssmmessages" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.enable_mitmproxy ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.public_subnets
  security_group_ids  = [aws_security_group.vpce[0].id]
  private_dns_enabled = true

  tags = { Name = "vpce-ec2messages" }
}
