resource "netbox_device_type" "c8000v" {
  manufacturer_id = netbox_manufacturer.cisco.id
  model           = "C8000V"
  slug            = "c8000v"
  u_height        = 0
}

data "netbox_device_type" "dl360" {
  slug       = "hpe-proliant-dl360-gen11"
  depends_on = [terraform_data.ndx_import]
}

data "netbox_device_type" "ap8965" {
  slug       = "apc-ap8965"
  depends_on = [terraform_data.ndx_import]
}

data "netbox_device_type" "n93180yc" {
  slug       = "cisco-n9k-c93180yc-fx3"
  depends_on = [terraform_data.ndx_import]
}

resource "netbox_device_role" "server" {
  name      = "server"
  color_hex = "00ff00"
}

resource "netbox_device_role" "pdu" {
  name      = "PDU"
  color_hex = "ff9900"
}

resource "netbox_device_role" "switch" {
  name      = "switch"
  color_hex = "2196f3"
}

resource "netbox_device" "ewr_app" {
  count          = 16
  name           = format("app%02d", count.index + 1)
  device_type_id = data.netbox_device_type.dl360.id
  role_id        = netbox_device_role.server.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  rack_id        = count.index < 8 ? netbox_rack.mmr2_rack3.id : netbox_rack.mmr2_rack4.id
  rack_face      = "front"
  rack_position  = 29 - (count.index % 8)
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "ewr_pdu" {
  for_each = {
    pdu1a = netbox_rack.mmr2_rack1.id
    pdu1b = netbox_rack.mmr2_rack1.id
    pdu2a = netbox_rack.mmr2_rack2.id
    pdu2b = netbox_rack.mmr2_rack2.id
    pdu3a = netbox_rack.mmr2_rack3.id
    pdu3b = netbox_rack.mmr2_rack3.id
    pdu4a = netbox_rack.mmr2_rack4.id
    pdu4b = netbox_rack.mmr2_rack4.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.ap8965.id
  role_id        = netbox_device_role.pdu.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "ewr_switch" {
  for_each = {
    sw3 = netbox_rack.mmr2_rack3.id
    sw4 = netbox_rack.mmr2_rack4.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.n93180yc.id
  role_id        = netbox_device_role.switch.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  rack_face      = "front"
  rack_position  = 40
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "jfk_app" {
  count          = 16
  name           = format("app%02d", count.index + 1)
  device_type_id = data.netbox_device_type.dl360.id
  role_id        = netbox_device_role.server.id
  site_id        = netbox_site.jfk.id
  location_id    = netbox_location.floor30.id
  rack_id        = count.index < 8 ? netbox_rack.floor30_rack3.id : netbox_rack.floor30_rack4.id
  rack_face      = "front"
  rack_position  = 29 - (count.index % 8)
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "jfk_switch" {
  for_each = {
    sw3 = netbox_rack.floor30_rack3.id
    sw4 = netbox_rack.floor30_rack4.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.n93180yc.id
  role_id        = netbox_device_role.switch.id
  site_id        = netbox_site.jfk.id
  location_id    = netbox_location.floor30.id
  rack_face      = "front"
  rack_position  = 40
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "jfk_pdu" {
  for_each = {
    pdu1a = netbox_rack.floor30_rack1.id
    pdu1b = netbox_rack.floor30_rack1.id
    pdu2a = netbox_rack.floor30_rack2.id
    pdu2b = netbox_rack.floor30_rack2.id
    pdu3a = netbox_rack.floor30_rack3.id
    pdu3b = netbox_rack.floor30_rack3.id
    pdu4a = netbox_rack.floor30_rack4.id
    pdu4b = netbox_rack.floor30_rack4.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.ap8965.id
  role_id        = netbox_device_role.pdu.id
  site_id        = netbox_site.jfk.id
  location_id    = netbox_location.floor30.id
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}
