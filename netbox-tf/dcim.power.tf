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

# neither the dl360 nor the nexus has power ports of its own, they arrive with the psu
# modules. module bays are auto-created from the device type template so terraform never
# learns their ids, and the provider has no module bay data source - hence the curl.
resource "terraform_data" "psu_modules" {
  for_each = {
    server = {
      part    = "P38995-B21"
      draw    = 300
      bays    = "&name=PSU1&name=PSU2"
      devices = concat(netbox_device.ewr_app[*].id, netbox_device.jfk_app[*].id)
    }
    switch = {
      part    = "NXA-PAC-650W-PE"
      draw    = 350
      bays    = "&name=PS1&name=PS2"
      devices = concat([for d in netbox_device.ewr_switch : d.id], [for d in netbox_device.jfk_switch : d.id])
    }
  }
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
      mt=$(api "$base/module-types/?part_number=${self.input.part}" | jq -e '.results[0].id')
      tpl=$(api "$base/power-port-templates/?module_type_id=$mt" | jq -e '.results[0].id')
      api -X PATCH "$base/power-port-templates/$tpl/" -d '{"allocated_draw": ${self.input.draw}}' >/dev/null
      for dev in ${join(" ", self.input.devices)}; do
        api "$base/module-bays/?device_id=$dev${self.input.bays}" \
        | jq -c --argjson dev "$dev" --argjson mt "$mt" \
            '.results[] | select(.installed_module == null)
             | {device: $dev, module_bay: .id, module_type: $mt, status: "active"}' \
        | while read -r module; do
            api -X POST "$base/modules/" -d "$module" >/dev/null
          done
      done
    EOT
  }
}

# ndx ships the ap8965's outlets with a feed_leg but no parent power_port, so netbox has
# nothing to roll the downstream draw up into. no way to adopt template-created outlets
# in terraform, so bulk patch the association on.
resource "terraform_data" "pdu_outlets" {
  input            = concat([for d in netbox_device.ewr_pdu : d.id], [for d in netbox_device.jfk_pdu : d.id])
  triggers_replace = concat([for d in netbox_device.ewr_pdu : d.id], [for d in netbox_device.jfk_pdu : d.id])

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
      for dev in ${join(" ", self.input)}; do
        whip=$(api -G "$base/power-ports/" \
          --data-urlencode "device_id=$dev" --data-urlencode "name=power whip" \
          | jq -e '.results[0].id')
        outlets=$(api "$base/power-outlets/?device_id=$dev&limit=0" \
          | jq -c --argjson whip "$whip" '[.results[] | {id, power_port: $whip}]')
        api -X PATCH "$base/power-outlets/" -d "$outlets" >/dev/null
      done
    EOT
  }
}

data "netbox_device_power_ports" "psu" {
  name_regex = "^PSU[12]$"
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
