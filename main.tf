resource "aws_security_group" "netbox_lab" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "allow_all_out" {
  security_group_id = aws_security_group.netbox_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.netbox_lab.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# resource "aws_vpc_security_group_ingress_rule" "allow_nbe_30k" {
#   security_group_id = aws_security_group.netbox_lab.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 30000
#   to_port           = 30000
#   ip_protocol       = "tcp"
# }

resource "aws_iam_role" "lab_instance_role" {
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
  role       = aws_iam_role.lab_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "lab_instance_profile" {
  role = aws_iam_role.lab_instance_role.name
}

data "aws_ssm_parameter" "al2023_ami_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "lab_instance" {
  ami                         = data.aws_ssm_parameter.al2023_ami_arm64.value
  instance_type               = "t3a.2xlarge"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.netbox_lab.id]
  user_data                   = file("${path.module}/userdata.sh")
  #user_data                   = file("${path.module}/nbe.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.lab_instance_profile.name

  root_block_device {
    volume_size = 100
  }
}