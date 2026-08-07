data "netbox_rack_type" "ar3355b2" {
  slug       = "apc-ar3355b2"
  depends_on = [terraform_data.ndx_import]
}

resource "netbox_rack_role" "networking" {
  name      = "Networking"
  color_hex = "4caf50"
}

resource "netbox_rack_role" "compute" {
  name      = "Compute"
  color_hex = "2196f3"
}

resource "netbox_rack" "mmr2_rack1" {
  name         = "rack1"
  role_id      = netbox_rack_role.networking.id
  status       = "active"
  site_id      = netbox_site.ewr.id
  location_id  = netbox_location.mmr2.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "mmr2_rack2" {
  name         = "rack2"
  status       = "active"
  role_id      = netbox_rack_role.networking.id
  site_id      = netbox_site.ewr.id
  location_id  = netbox_location.mmr2.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "mmr2_rack3" {
  name         = "rack3"
  status       = "active"
  role_id      = netbox_rack_role.compute.id
  site_id      = netbox_site.ewr.id
  location_id  = netbox_location.mmr2.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "mmr2_rack4" {
  name         = "rack4"
  status       = "active"
  role_id      = netbox_rack_role.compute.id
  site_id      = netbox_site.ewr.id
  location_id  = netbox_location.mmr2.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "floor30_rack1" {
  name         = "rack1"
  status       = "active"
  role_id      = netbox_rack_role.networking.id
  site_id      = netbox_site.jfk.id
  location_id  = netbox_location.floor30.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "floor30_rack2" {
  name         = "rack2"
  status       = "active"
  role_id      = netbox_rack_role.networking.id
  site_id      = netbox_site.jfk.id
  location_id  = netbox_location.floor30.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "floor30_rack3" {
  name         = "rack3"
  status       = "active"
  role_id      = netbox_rack_role.compute.id
  site_id      = netbox_site.jfk.id
  location_id  = netbox_location.floor30.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}

resource "netbox_rack" "floor30_rack4" {
  name         = "rack4"
  status       = "active"
  role_id      = netbox_rack_role.compute.id
  site_id      = netbox_site.jfk.id
  location_id  = netbox_location.floor30.id
  tenant_id    = netbox_tenant.vaulter.id
  rack_type_id = data.netbox_rack_type.ar3355b2.id
}
