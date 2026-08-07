resource "netbox_manufacturer" "cisco" {
  name = "Cisco"
}

resource "netbox_manufacturer" "apc" {
  name = "APC"
}

resource "netbox_manufacturer" "hpe" {
  name = "HPE"
}

# things to import from NDX
locals {
  ndx_ids = [
    "hpe/hpe-proliant-dl360-gen11",
    "hpe/P38995-B21",
    "schneider-electric/apc-ar3355b2",
    "schneider-electric/apc-ap8965",
  ]
}

# tfdata/localexec/curl because there is no ndx in the tf provider, but there is a rest api
resource "terraform_data" "ndx_import" {
  input            = local.ndx_ids
  triggers_replace = local.ndx_ids
  depends_on       = [netbox_manufacturer.apc, netbox_manufacturer.hpe]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      curl -sS --fail-with-body -X POST "${var.netbox_server_url}/api/plugins/ndx/import/" \
        -H "Authorization: Token ${var.netbox_api_token}" \
        -H "Content-Type: application/json" \
        -d '${jsonencode({ ndx_ids = self.input })}' \
      | jq -e 'all(.results[]; .success)' >/dev/null
    EOT
  }
}

resource "netbox_site_group" "datacenter" {
  name = "Data Centers"
}

resource "netbox_site" "ewr" {
  name             = "EWR"
  facility         = "165 Halsey"
  group_id         = netbox_site_group.datacenter.id
  tenant_id        = netbox_tenant.vaulter.id
  description      = "https://www.165halsey.com"
  timezone         = "America/New_York"
  physical_address = "165 Halsey Street, Newark, NJ 07102"
  latitude         = "40.736906"
  longitude        = "-74.173213"
}

resource "netbox_location" "mmr2" {
  name    = "MMR2"
  site_id = netbox_site.ewr.id
}

resource "netbox_site" "jfk" {
  name             = "JFK"
  facility         = "375 Pearl"
  group_id         = netbox_site_group.datacenter.id
  tenant_id        = netbox_tenant.vaulter.id
  description      = "https://375pearl.com"
  timezone         = "America/New_York"
  physical_address = "375 Pearl St, New York, NY 10038"
  latitude         = "40.710945"
  longitude        = "-74.001178"
}

resource "netbox_location" "floor30" {
  name    = "30th Floor"
  site_id = netbox_site.jfk.id
}

resource "netbox_site" "hq" {
  name             = "Headquarters"
  tenant_id        = netbox_tenant.vaulter.id
  timezone         = "America/New_York"
  physical_address = "209 Elizabeth St, New York, NY 10012"
  latitude         = "40.722790"
  longitude        = "-73.994690"
}
