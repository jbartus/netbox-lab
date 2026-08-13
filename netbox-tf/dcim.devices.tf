# a compute rack, read top down: switch at u40, then three groups of servers separated by
# 2u gaps. each group hangs off one feed leg and uses all seven of that leg's c13 outlets -
# the switch takes leg a's first one. u position and outlet travel together so they can't
# drift apart.
locals {
  compute_slots = [
    # leg a - six, because the switch has outlet 1
    { u = 37, outlet = "power outlet 2" },
    { u = 36, outlet = "power outlet 3" },
    { u = 35, outlet = "power outlet 4" },
    { u = 34, outlet = "power outlet 5" },
    { u = 33, outlet = "power outlet 6" },
    { u = 32, outlet = "power outlet 7" },
    # leg b
    { u = 29, outlet = "power outlet 9" },
    { u = 28, outlet = "power outlet 10" },
    { u = 27, outlet = "power outlet 11" },
    { u = 26, outlet = "power outlet 12" },
    { u = 25, outlet = "power outlet 13" },
    { u = 24, outlet = "power outlet 14" },
    { u = 23, outlet = "power outlet 15" },
    # leg c
    { u = 20, outlet = "power outlet 17" },
    { u = 19, outlet = "power outlet 18" },
    { u = 18, outlet = "power outlet 19" },
    { u = 17, outlet = "power outlet 20" },
    { u = 16, outlet = "power outlet 21" },
    { u = 15, outlet = "power outlet 22" },
    { u = 14, outlet = "power outlet 23" },
  ]
  servers_per_rack = length(local.compute_slots)
}

# every device of each kind, across both sites. apps are counted, the rest are keyed.
locals {
  servers = netbox_device.ewr_app[*].id
  leaves  = values(netbox_device.ewr_switch)[*].id
  spines  = concat(values(netbox_device.ewr_spine)[*].id, values(netbox_device.jfk_spine)[*].id)
  routers = concat(values(netbox_device.ewr_rtr)[*].id, values(netbox_device.jfk_rtr)[*].id)
  oobs    = concat(values(netbox_device.ewr_oob)[*].id, values(netbox_device.jfk_oob)[*].id)
}

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

data "netbox_device_type" "n9336c" {
  slug       = "cisco-n9k-c9336c-fx2"
  depends_on = [terraform_data.ndx_import]
}

data "netbox_device_type" "c9300" {
  slug       = "cisco-c9300-48t"
  depends_on = [terraform_data.ndx_import]
}

data "netbox_device_type" "mx204" {
  slug       = "juniper-mx204"
  depends_on = [terraform_data.ndx_import]
}

resource "netbox_device_role" "server" {
  name      = "server"
  color_hex = "8bc34a"
}

resource "netbox_device_role" "pdu" {
  name      = "PDU"
  color_hex = "ff9800"
}

resource "netbox_device_role" "switch" {
  name      = "switch"
  color_hex = "00bcd4"
}

resource "netbox_device_role" "router" {
  name      = "router"
  color_hex = "9c27b0"
}

resource "netbox_device_role" "spine" {
  name      = "spine"
  color_hex = "3f51b5"
}

resource "netbox_device_role" "oob" {
  name      = "oob"
  color_hex = "607d8b"
}

resource "netbox_device" "ewr_app" {
  count          = local.servers_per_rack * 2
  name           = format("app%02d", count.index + 1)
  device_type_id = data.netbox_device_type.dl360.id
  role_id        = netbox_device_role.server.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  rack_id        = count.index < local.servers_per_rack ? netbox_rack.mmr2_rack3.id : netbox_rack.mmr2_rack4.id
  rack_face      = "front"
  rack_position  = local.compute_slots[count.index % local.servers_per_rack].u
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

resource "netbox_device" "ewr_rtr" {
  for_each = {
    rtr1 = netbox_rack.mmr2_rack1.id
    rtr2 = netbox_rack.mmr2_rack2.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.mx204.id
  role_id        = netbox_device_role.router.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  rack_face      = "front"
  rack_position  = 44
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "ewr_spine" {
  for_each = {
    spine1 = netbox_rack.mmr2_rack1.id
    spine2 = netbox_rack.mmr2_rack2.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.n9336c.id
  role_id        = netbox_device_role.spine.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  rack_face      = "front"
  rack_position  = 42
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "ewr_oob" {
  for_each = {
    oob1 = netbox_rack.mmr2_rack1.id
    oob2 = netbox_rack.mmr2_rack2.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.c9300.id
  role_id        = netbox_device_role.oob.id
  site_id        = netbox_site.ewr.id
  location_id    = netbox_location.mmr2.id
  rack_face      = "front"
  rack_position  = 40
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}



resource "netbox_device" "jfk_rtr" {
  for_each = {
    rtr1 = netbox_rack.floor30_rack1.id
    rtr2 = netbox_rack.floor30_rack2.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.mx204.id
  role_id        = netbox_device_role.router.id
  site_id        = netbox_site.jfk.id
  location_id    = netbox_location.floor30.id
  rack_face      = "front"
  rack_position  = 44
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "jfk_spine" {
  for_each = {
    spine1 = netbox_rack.floor30_rack1.id
    spine2 = netbox_rack.floor30_rack2.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.n9336c.id
  role_id        = netbox_device_role.spine.id
  site_id        = netbox_site.jfk.id
  location_id    = netbox_location.floor30.id
  rack_face      = "front"
  rack_position  = 42
  tenant_id      = netbox_tenant.vaulter.id
  status         = "active"
}

resource "netbox_device" "jfk_oob" {
  for_each = {
    oob1 = netbox_rack.floor30_rack1.id
    oob2 = netbox_rack.floor30_rack2.id
  }
  name           = each.key
  rack_id        = each.value
  device_type_id = data.netbox_device_type.c9300.id
  role_id        = netbox_device_role.oob.id
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
