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

# one entry per build: what psu goes in it, what that build actually pulls per port, and
# which bays to fill. draw belongs to the build, not the part - two builds can share a psu
# and pull different wattage.
locals {
  psu_builds = {
    server = {
      part    = "P38995-B21"
      draw    = 300
      bays    = ["PSU1", "PSU2"]
      devices = local.servers
    }
    switch = {
      part    = "NXA-PAC-650W-PE"
      draw    = 350
      bays    = ["PS1", "PS2"]
      devices = local.leaves
    }
    spine = {
      part    = "NXA-PAC-1100W-PE2"
      draw    = 400
      bays    = ["PS1", "PS2"]
      devices = local.spines
    }
    router = {
      part    = "JPSU-650W-AC-AFO"
      draw    = 300
      bays    = ["Power Supply 0", "Power Supply 1"]
      devices = local.routers
    }
    oob = {
      part    = "PWR-C1-350WAC"
      draw    = 150
      bays    = ["PS-A", "PS-B"]
      devices = local.oobs
    }
  }
}

# none of these platforms has power ports of its own, they arrive with the psu modules.
# module bays are auto-created from the device type template so terraform never learns
# their ids, and the provider has no module bay data source - hence the curl.
resource "terraform_data" "psu_modules" {
  for_each         = local.psu_builds
  input            = each.value
  triggers_replace = each.value
  depends_on       = [terraform_data.ndx_import]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      api() {
        curl -sS --fail-with-body \
          -H "Authorization: Token ${var.netbox_api_token}" \
          -H "Content-Type: application/json" "$@"
      }
      base="${var.netbox_server_url}/api/dcim"
      devices="${join("", [for id in self.input.devices : "&device_id=${id}"])}"
      mt=$(api "$base/module-types/?part_number=${self.input.part}" | jq -e '.results[0].id')

      # fill every empty psu bay on this build's devices, in one create
      modules=$(api "$base/module-bays/?limit=0$devices" \
        | jq -c --argjson mt "$mt" --argjson bays '${jsonencode(self.input.bays)}' \
            '[.results[] | select(.installed_module == null) | select(.name | IN($bays[]))
              | {device: .device.id, module_bay: .id, module_type: $mt, status: "active"}]')
      [ "$modules" = "[]" ] || api -X POST "$base/modules/" -d "$modules" >/dev/null

      # then set allocated draw on the ports those modules brought with them
      draws=$(api "$base/power-ports/?limit=0$devices" \
        | jq -c --argjson draw ${self.input.draw} \
            '[.results[] | select(.module != null) | {id, allocated_draw: $draw}]')
      [ "$draws" = "[]" ] || api -X PATCH "$base/power-ports/" -d "$draws" >/dev/null
    EOT
  }
}


data "netbox_device_power_ports" "psu" {
  name_regex = "^(PSU[12]|PEM [01]|PS-[AB])$"
  depends_on = [terraform_data.psu_modules]
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
