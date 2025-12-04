variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "value for the AWS region to deploy resources in, e.g. us-east-1, eu-west-2."
  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca)-[a-z]+-[1-9]$", var.aws_region))
    error_message = "Invalid AWS region format. Use 'us-east-1', 'eu-west-2', etc."
  }
}

variable "enable_community" {
  type    = bool
  default = false
}

variable "enable_ansible" {
  type    = bool
  default = false
}

variable "enable_enterprise" {
  type    = bool
  default = false
}

variable "nbe_token" {
  type        = string
  sensitive   = true
  description = "token supplied by Netbox Labs for your NetBox Enterprise instance."
  validation {
    condition     = length(var.nbe_token) > 0
    error_message = "NetBox Enterprise token must not be empty."
  }
}

variable "nbe_console_password" {
  type        = string
  sensitive   = true
  description = "A password of at least 6 characters for the NetBox Enterprise console user."
  validation {
    condition     = length(var.nbe_console_password) >= 6
    error_message = "NetBox Enterprise console password must be at least 6 characters long."
  }
}

variable "nbe_admin_password" {
  type        = string
  sensitive   = true
  description = "A password of at least 12 characters for the NetBox Enterprise admin user."
  validation {
    condition     = length(var.nbe_admin_password) >= 12
    error_message = "NetBox Enterprise admin password must be at least 12 characters long."
  }
}

variable "nbe_release_channel" {
  type        = string
  default     = "stable"
  description = "Release channel for NetBox Enterprise."
}

variable "enable_discovery" {
  type    = bool
  default = false
}

variable "enable_ldap" {
  type    = bool
  default = false
}

variable "enable_saml" {
  type    = bool
  default = false
}

variable "enable_eks" {
  type    = bool
  default = false
}

variable "enable_postgres" {
  type    = bool
  default = false
}

variable "postgres_password" {
  type        = string
  sensitive   = true
  description = "A password of at least 8 characters for the PostgreSQL database."
  validation {
    condition     = length(var.postgres_password) >= 8
    error_message = "PostgreSQL password must be at least 8 characters long."
  }
}

variable "enable_ubuntu" {
  type    = bool
  default = false
}

variable "enable_rhel" {
  type    = bool
  default = false
}