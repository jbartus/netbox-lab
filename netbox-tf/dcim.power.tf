resource "netbox_power_panel" "ewr_a" {
  name    = "Panel A"
  site_id = netbox_site.ewr.id
}

resource "netbox_power_panel" "ewr_b" {
  name    = "Panel B"
  site_id = netbox_site.ewr.id
}

resource "netbox_power_panel" "jfk_a" {
  name    = "Panel A"
  site_id = netbox_site.jfk.id
}

resource "netbox_power_panel" "jfk_b" {
  name    = "Panel B"
  site_id = netbox_site.jfk.id
}

# 208v 30a three-phase to match the ap8965's l21-30p whip
resource "netbox_power_feed" "ewr_a" {
  for_each = {
    rack1 = netbox_rack.mmr2_rack1.id
    rack2 = netbox_rack.mmr2_rack2.id
    rack3 = netbox_rack.mmr2_rack3.id
    rack4 = netbox_rack.mmr2_rack4.id
  }
  name                    = "${each.key}-a"
  power_panel_id          = netbox_power_panel.ewr_a.id
  rack_id                 = each.value
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_power_feed" "ewr_b" {
  for_each = {
    rack1 = netbox_rack.mmr2_rack1.id
    rack2 = netbox_rack.mmr2_rack2.id
    rack3 = netbox_rack.mmr2_rack3.id
    rack4 = netbox_rack.mmr2_rack4.id
  }
  name                    = "${each.key}-b"
  power_panel_id          = netbox_power_panel.ewr_b.id
  rack_id                 = each.value
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_power_feed" "jfk_a" {
  for_each = {
    rack1 = netbox_rack.floor30_rack1.id
    rack2 = netbox_rack.floor30_rack2.id
    rack3 = netbox_rack.floor30_rack3.id
    rack4 = netbox_rack.floor30_rack4.id
  }
  name                    = "${each.key}-a"
  power_panel_id          = netbox_power_panel.jfk_a.id
  rack_id                 = each.value
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_power_feed" "jfk_b" {
  for_each = {
    rack1 = netbox_rack.floor30_rack1.id
    rack2 = netbox_rack.floor30_rack2.id
    rack3 = netbox_rack.floor30_rack3.id
    rack4 = netbox_rack.floor30_rack4.id
  }
  name                    = "${each.key}-b"
  power_panel_id          = netbox_power_panel.jfk_b.id
  rack_id                 = each.value
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

locals {
  # what module goes in which bays. psus, nics, anything bay-mounted installs the same way.
  modules = {
    server_psu = { part = "P38995-B21", bays = ["PSU1", "PSU2"], devices = local.servers }
    server_nic = { part = "P42044-B21", bays = ["OCP1"], devices = local.servers }
    switch_psu = { part = "NXA-PAC-650W-PE", bays = ["PS1", "PS2"], devices = local.leaves }
    spine_psu  = { part = "NXA-PAC-1100W-PE2", bays = ["PS1", "PS2"], devices = local.spines }
    router_psu = { part = "JPSU-650W-AC-AFO", bays = ["Power Supply 0", "Power Supply 1"], devices = local.routers }
    oob_psu    = { part = "PWR-C1-350WAC", bays = ["PS-A", "PS-B"], devices = local.oobs }
  }

  # what each build actually pulls, per power port. a property of the build, not of the psu
  # part - two builds can share a psu and draw different wattage. nics have no power port,
  # so they are simply absent here.
  draws = {
    server = { watts = 300, devices = local.servers }
    switch = { watts = 350, devices = local.leaves }
    spine  = { watts = 400, devices = local.spines }
    router = { watts = 300, devices = local.routers }
    oob    = { watts = 150, devices = local.oobs }
  }
}

# none of these platforms has power ports of its own, they arrive with the psu modules.
# module bays are auto-created from the device type template so terraform never learns
# their ids, and the provider has no module bay data source - hence the curl.
resource "terraform_data" "modules" {
  for_each         = local.modules
  input            = each.value
  triggers_replace = each.value
  depends_on       = [terraform_data.ndx_import]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install-modules.sh"
    environment = {
      NETBOX_URL   = var.netbox_server_url
      NETBOX_TOKEN = var.netbox_api_token
      PART         = self.input.part
      BAYS         = join("\n", self.input.bays)
      DEVICES      = join(" ", self.input.devices)
    }
  }
}

resource "terraform_data" "allocated_draw" {
  for_each         = local.draws
  input            = each.value
  triggers_replace = each.value
  depends_on       = [terraform_data.modules]

  provisioner "local-exec" {
    command = "${path.module}/scripts/set-allocated-draw.sh"
    environment = {
      NETBOX_URL   = var.netbox_server_url
      NETBOX_TOKEN = var.netbox_api_token
      WATTS        = self.input.watts
      DEVICES      = join(" ", self.input.devices)
    }
  }
}


data "netbox_device_power_ports" "psu" {
  name_regex = "^(PSU[12]|PEM [01]|PS-[AB])$"
  depends_on = [terraform_data.modules]
}

data "netbox_device_power_ports" "whip" {
  name_regex = "^power whip$"
  depends_on = [netbox_device.ewr_pdu, netbox_device.jfk_pdu]
}

data "netbox_device_power_outlets" "pdu" {
  depends_on = [netbox_device.ewr_pdu, netbox_device.jfk_pdu]
}

locals {
  psu_ports   = { for p in data.netbox_device_power_ports.psu.power_ports : "${p.device_id}/${p.name}" => p.id }
  whip_ports  = { for p in data.netbox_device_power_ports.whip.power_ports : p.device_id => p.id }
  pdu_outlets = { for o in data.netbox_device_power_outlets.pdu.power_outlets : "${o.device_id}/${o.name}" => o.id }
}
