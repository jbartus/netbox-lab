variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "nbe_token" {
  type      = string
  sensitive = true
}

variable "nbe_console_password" {
  type      = string
  sensitive = true
}

variable "nbe_admin_password" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}