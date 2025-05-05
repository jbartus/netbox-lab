resource "aws_security_group" "nbc" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "nbc_allow_all_out" {
  security_group_id = aws_security_group.nbc.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "nbc_allow_https_in" {
  security_group_id = aws_security_group.nbc.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_iam_role" "nbc_instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nbc_ssm_policy_attachment" {
  role       = aws_iam_role.nbc_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nbc_instance_profile" {
  role = aws_iam_role.nbc_instance_role.name
}

data "aws_ssm_parameter" "al2023_ami_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "nbc_instance" {
  ami                         = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type               = "t4g.xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.nbc.id]
  user_data                   = file("${path.module}/nbc.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.nbc_instance_profile.name
}