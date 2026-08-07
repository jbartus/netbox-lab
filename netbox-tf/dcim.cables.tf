locals {
  # the ap8965's c19 outlets are 8, 16 and 24; take c13s spread over all three feed legs.
  # outlet 1 is the cord end, so read the list as top of pdu down: the switch at u40 takes
  # it, then app01 at u29 on down. nine devices in a rack, 3 per leg.
  switch_outlet = "power outlet 1"
  psu_outlets = [
    "power outlet 2", "power outlet 3",
    "power outlet 9", "power outlet 10", "power outlet 11",
    "power outlet 17", "power outlet 18", "power outlet 19",
  ]
}

resource "netbox_cable" "ewr_whip" {
  for_each = {
    pdu1a = netbox_power_feed.ewr_a["rack1"].id
    pdu1b = netbox_power_feed.ewr_b["rack1"].id
    pdu2a = netbox_power_feed.ewr_a["rack2"].id
    pdu2b = netbox_power_feed.ewr_b["rack2"].id
    pdu3a = netbox_power_feed.ewr_a["rack3"].id
    pdu3b = netbox_power_feed.ewr_b["rack3"].id
    pdu4a = netbox_power_feed.ewr_a["rack4"].id
    pdu4b = netbox_power_feed.ewr_b["rack4"].id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.whip_ports[netbox_device.ewr_pdu[each.key].id]
  }
  b_termination {
    object_type = "dcim.powerfeed"
    object_id   = each.value
  }
}

resource "netbox_cable" "jfk_whip" {
  for_each = {
    pdu1a = netbox_power_feed.jfk_a["rack1"].id
    pdu1b = netbox_power_feed.jfk_b["rack1"].id
    pdu2a = netbox_power_feed.jfk_a["rack2"].id
    pdu2b = netbox_power_feed.jfk_b["rack2"].id
    pdu3a = netbox_power_feed.jfk_a["rack3"].id
    pdu3b = netbox_power_feed.jfk_b["rack3"].id
    pdu4a = netbox_power_feed.jfk_a["rack4"].id
    pdu4b = netbox_power_feed.jfk_b["rack4"].id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.whip_ports[netbox_device.jfk_pdu[each.key].id]
  }
  b_termination {
    object_type = "dcim.powerfeed"
    object_id   = each.value
  }
}

resource "netbox_cable" "ewr_switch_psu1" {
  for_each = {
    sw3 = netbox_device.ewr_pdu["pdu3a"].id
    sw4 = netbox_device.ewr_pdu["pdu4a"].id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.ewr_switch[each.key].id}/PSU1"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${each.value}/${local.switch_outlet}"]
  }
}

resource "netbox_cable" "ewr_switch_psu2" {
  for_each = {
    sw3 = netbox_device.ewr_pdu["pdu3b"].id
    sw4 = netbox_device.ewr_pdu["pdu4b"].id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.ewr_switch[each.key].id}/PSU2"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${each.value}/${local.switch_outlet}"]
  }
}

resource "netbox_cable" "jfk_switch_psu1" {
  for_each = {
    sw3 = netbox_device.jfk_pdu["pdu3a"].id
    sw4 = netbox_device.jfk_pdu["pdu4a"].id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.jfk_switch[each.key].id}/PSU1"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${each.value}/${local.switch_outlet}"]
  }
}

resource "netbox_cable" "jfk_switch_psu2" {
  for_each = {
    sw3 = netbox_device.jfk_pdu["pdu3b"].id
    sw4 = netbox_device.jfk_pdu["pdu4b"].id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.jfk_switch[each.key].id}/PSU2"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${each.value}/${local.switch_outlet}"]
  }
}

resource "netbox_cable" "ewr_psu1" {
  count  = 16
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.ewr_app[count.index].id}/PSU1"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${count.index < 8 ? netbox_device.ewr_pdu["pdu3a"].id : netbox_device.ewr_pdu["pdu4a"].id}/${local.psu_outlets[count.index % 8]}"]
  }
}

resource "netbox_cable" "ewr_psu2" {
  count  = 16
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.ewr_app[count.index].id}/PSU2"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${count.index < 8 ? netbox_device.ewr_pdu["pdu3b"].id : netbox_device.ewr_pdu["pdu4b"].id}/${local.psu_outlets[count.index % 8]}"]
  }
}

resource "netbox_cable" "jfk_psu1" {
  count  = 16
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.jfk_app[count.index].id}/PSU1"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${count.index < 8 ? netbox_device.jfk_pdu["pdu3a"].id : netbox_device.jfk_pdu["pdu4a"].id}/${local.psu_outlets[count.index % 8]}"]
  }
}

resource "netbox_cable" "jfk_psu2" {
  count  = 16
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.jfk_app[count.index].id}/PSU2"]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${count.index < 8 ? netbox_device.jfk_pdu["pdu3b"].id : netbox_device.jfk_pdu["pdu4b"].id}/${local.psu_outlets[count.index % 8]}"]
  }
}
