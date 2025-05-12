resource "aws_security_group" "nbe_lab" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "nbe_allow_all_out" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "nbe_allow_https_in" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nbe_allow_30k_in" {
  security_group_id = aws_security_group.nbe_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 30000
  ip_protocol       = "tcp"
}

resource "aws_iam_role" "nbe_instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nbe_ssm_policy_attachment" {
  role       = aws_iam_role.nbe_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nbe_instance_profile" {
  role = aws_iam_role.nbe_instance_role.name
}

data "aws_ssm_parameter" "al2023_ami_x86-64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "nbe_instance" {
  ami                         = data.aws_ssm_parameter.al2023_ami_x86-64.value
  instance_type               = "t3a.2xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.nbe_lab.id]
  user_data                   = templatefile("${path.module}/nbe.sh.tpl", { nbe_token = var.nbe_token })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.nbe_instance_profile.name

  root_block_device {
    volume_size = 100
  }
}

output "nbe_ssm_command" {
  value = "aws --region us-east-1 ssm start-session --target ${aws_instance.nbe_instance.id}"
}

output "nbe_console_url" {
  value = "https://${aws_instance.nbe_instance.public_ip}:30000"
}