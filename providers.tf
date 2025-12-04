terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "external" "whoami" {
  program = ["sh", "-c", "echo '{\"username\":\"'$(whoami)'\"}'"]
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Owner = data.external.whoami.result.username
    }
  }
}

data "aws_ssm_parameter" "al2023_ami_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_ssm_parameter" "al2023_ami_x86-64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "ubuntu_2404_ami_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ssm_parameter" "windows_server_2022_ami_x86_64" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

data "aws_ami" "rhel_97_ami_x86_64" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9.7*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}