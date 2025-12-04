terraform {
  required_providers {
    netbox = {
      source = "e-breuninger/netbox"
    }
  }
}

provider "netbox" {
  server_url           = "FIXME"
  api_token            = "FIXME"
  allow_insecure_https = true
}

resource "netbox_manufacturer" "cisco" {
  name = "Cisco"
}

resource "netbox_device_type" "c8000v" {
  manufacturer_id = netbox_manufacturer.cisco.id
  model           = "C8000V"
  slug            = "c8000v"
}

resource "netbox_manufacturer" "apc" {
  name = "APC"
}

resource "netbox_manufacturer" "hpe" {
  name = "HPE"
}

resource "netbox_device_role" "server" {
  name      = "server"
  color_hex = "00ff00"
}

resource "netbox_device_role" "pdu" {
  name      = "PDU"
  color_hex = "ff9900"
}

resource "netbox_rack_type" "ar3350b2" {
  manufacturer_id = netbox_manufacturer.apc.id
  model           = "AR3350B2"
  slug            = "ar3350b2"
  description     = "APC NetShelter SX Server Rack Gen 2"
  form_factor     = "4-post-cabinet"
  u_height        = 42
  width           = 19
  starting_unit   = 1
  outer_unit      = "mm"
  outer_width     = 750
  outer_depth     = 1200
  comments        = "https://www.apc.com/us/en/product/AR3350B2/apc-netshelter-sx-server-rack-gen-2-42u-1991h-x-750w-x-1200d-mm-with-sides-black-taa/"
}

resource "netbox_tenant" "vaulter" {
  name = "Vaulter"
}

resource "netbox_rack_role" "networking" {
  name      = "Networking"
  color_hex = "4caf50"
}

resource "netbox_rack_role" "compute" {
  name      = "Compute"
  color_hex = "2196f3"
}

resource "netbox_site" "_165halsey" {
  name             = "165 Halsey"
  description      = "https://www.165halsey.com"
  timezone         = "America/New_York"
  physical_address = "165 Halsey Street, Newark, NJ 07102"
  latitude         = "40.736906"
  longitude        = "-74.173213"
}

resource "netbox_contact_role" "colomgr" {
  name = "Colocation Manager"
}

resource "netbox_contact" "joep" {
  name  = "Joe P."
  email = "joep@165halsey.com"
  phone = "973-555-2501"
}

resource "netbox_contact_assignment" "joep_colomgr" {
  content_type = "dcim.site"
  object_id    = netbox_site._165halsey.id
  contact_id   = netbox_contact.joep.id
  role_id      = netbox_contact_role.colomgr.id
}

resource "netbox_config_context" "ewr_ntp" {
  name  = "ewr-ntp"
  sites = [netbox_site._165halsey.id]
  data = jsonencode({
    ntp_servers = [
      "0.pool.ntp.org",
      "1.pool.ntp.org",
    ]
  })
}

resource "netbox_location" "mmr2" {
  name    = "MMR2"
  site_id = netbox_site._165halsey.id
}

resource "netbox_power_panel" "panel_a" {
  name    = "Panel A"
  site_id = netbox_site._165halsey.id
}

resource "netbox_power_panel" "panel_b" {
  name    = "Panel B"
  site_id = netbox_site._165halsey.id
}

resource "netbox_power_feed" "a-power" {
  name                    = "a-power"
  power_panel_id          = netbox_power_panel.panel_a.id
  rack_id                 = netbox_rack.mmr2_rack1.id
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 120
  amperage                = 20
  phase                   = "single-phase"
  max_percent_utilization = 80
}

resource "netbox_power_feed" "b-power" {
  name                    = "b-power"
  power_panel_id          = netbox_power_panel.panel_b.id
  rack_id                 = netbox_rack.mmr2_rack1.id
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 120
  amperage                = 20
  phase                   = "single-phase"
  max_percent_utilization = 80
}

resource "netbox_rack" "mmr2_rack1" {
  name        = "rack1"
  role_id     = netbox_rack_role.networking.id
  status      = "active"
  site_id     = netbox_site._165halsey.id
  location_id = netbox_location.mmr2.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_rack" "mmr2_rack2" {
  name        = "rack2"
  status      = "active"
  role_id     = netbox_rack_role.networking.id
  site_id     = netbox_site._165halsey.id
  location_id = netbox_location.mmr2.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_rack" "mmr2_rack3" {
  name        = "rack3"
  status      = "active"
  role_id     = netbox_rack_role.compute.id
  site_id     = netbox_site._165halsey.id
  location_id = netbox_location.mmr2.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_rack" "mmr2_rack4" {
  name        = "rack4"
  status      = "active"
  role_id     = netbox_rack_role.compute.id
  site_id     = netbox_site._165halsey.id
  location_id = netbox_location.mmr2.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_site" "_375pearl" {
  name             = "375 Pearl"
  description      = "https://375pearl.com"
  timezone         = "America/New_York"
  physical_address = "375 Pearl St, New York, NY 10038"
  latitude         = "40.710945"
  longitude        = "-74.001178"
}

resource "netbox_config_context" "jfk_ntp" {
  name  = "jfk-ntp"
  sites = [netbox_site._165halsey.id]
  data = jsonencode({
    ntp_servers = [
      "2.pool.ntp.org",
      "3.pool.ntp.org",
    ]
  })
}

resource "netbox_location" "floor30" {
  name    = "30th Floor"
  site_id = netbox_site._375pearl.id
}

resource "netbox_rack" "floor30_rack1" {
  name        = "rack1"
  status      = "active"
  role_id     = netbox_rack_role.networking.id
  site_id     = netbox_site._375pearl.id
  location_id = netbox_location.floor30.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_rack" "floor30_rack2" {
  name        = "rack2"
  status      = "active"
  role_id     = netbox_rack_role.networking.id
  site_id     = netbox_site._375pearl.id
  location_id = netbox_location.floor30.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_rack" "floor30_rack3" {
  name        = "rack3"
  status      = "active"
  role_id     = netbox_rack_role.compute.id
  site_id     = netbox_site._375pearl.id
  location_id = netbox_location.floor30.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_rack" "floor30_rack4" {
  name        = "rack4"
  status      = "active"
  role_id     = netbox_rack_role.compute.id
  site_id     = netbox_site._375pearl.id
  location_id = netbox_location.floor30.id
  tenant_id   = netbox_tenant.vaulter.id
  outer_width = 24
  outer_depth = 40
  outer_unit  = "in"
  u_height    = 42
  width       = 19
}

resource "netbox_config_template" "ios_ntp" {
  name          = "ios-ntp"
  template_code = "{% for ntp in ntp_servers %}\nntp server {{ ntp }}\n{% endfor %}"
}
