terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "external" "whoami" {
  program = ["sh", "-c", "echo '{\"username\":\"'$(whoami)'\"}'"]
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Owner = data.external.whoami.result.username
    }
  }
}