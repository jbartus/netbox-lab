terraform {
  required_providers {
    netbox = {
      source = "e-breuninger/netbox"
    }
  }
}

variable "netbox_server_url" {
  type = string
}

variable "netbox_api_token" {
  type      = string
  sensitive = true
}

provider "netbox" {
  server_url           = var.netbox_server_url
  api_token            = var.netbox_api_token
  allow_insecure_https = true
  # default is 10s, which cloud blows past under parallel writes and orphans the object
  request_timeout = 60
}
