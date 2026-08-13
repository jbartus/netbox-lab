resource "netbox_prefix" "ewr_internet" {
  prefix      = "64.125.196.24/30"
  status      = "active"
  site_id     = netbox_site.ewr.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "Zayo uplink transit"
}

resource "netbox_ip_address" "ewr_internet_gw" {
  ip_address  = "64.125.196.25/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  description = "Zayo upstream gateway / default route"
}

resource "netbox_ip_address" "ewr_cpe_outside" {
  ip_address  = "64.125.196.26/30"
  status      = "reserved"
  tenant_id   = netbox_tenant.vaulter.id
  description = "165 Halsey CPE outside interface"
}

resource "netbox_prefix" "jfk_internet" {
  prefix      = "12.185.44.72/30"
  status      = "active"
  site_id     = netbox_site.jfk.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "AT&T uplink transit"
}

resource "netbox_ip_address" "jfk_internet_gw" {
  ip_address  = "12.185.44.73/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  description = "AT&T upstream gateway / default route"
}

resource "netbox_ip_address" "jfk_cpe_outside" {
  ip_address  = "12.185.44.74/30"
  status      = "reserved"
  tenant_id   = netbox_tenant.vaulter.id
  description = "375 Pearl CPE outside interface"
}

resource "netbox_prefix" "hq_internet" {
  prefix      = "96.114.212.184/30"
  status      = "active"
  site_id     = netbox_site.hq.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "Comcast uplink transit"
}

resource "netbox_ip_address" "hq_internet_gw" {
  ip_address  = "96.114.212.185/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  description = "Comcast upstream gateway / default route"
}

resource "netbox_ip_address" "hq_cpe_outside" {
  ip_address  = "96.114.212.186/30"
  status      = "reserved"
  tenant_id   = netbox_tenant.vaulter.id
  description = "HQ CPE outside interface"
}

# a role is shared by a vlan and the prefix assigned to it, per netbox convention
resource "netbox_ipam_role" "networking" {
  name = "Networking"
  slug = "networking"
}

resource "netbox_ipam_role" "mgmt" {
  name = "Management"
  slug = "mgmt"
}

resource "netbox_ipam_role" "compute" {
  name = "Compute"
  slug = "compute"
}

resource "netbox_prefix" "ewr_supernet" {
  prefix      = "10.1.0.0/16"
  status      = "container"
  site_id     = netbox_site.ewr.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "EWR"
}

resource "netbox_prefix" "jfk_supernet" {
  prefix      = "10.2.0.0/16"
  status      = "container"
  site_id     = netbox_site.jfk.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "JFK"
}

# a group is what actually enforces vid uniqueness - site alone does not
resource "netbox_vlan_group" "ewr" {
  name       = "EWR"
  slug       = "ewr"
  scope_type = "dcim.site"
  scope_id   = netbox_site.ewr.id
  vid_ranges = [[100, 399]]
}

resource "netbox_vlan_group" "jfk" {
  name       = "JFK"
  slug       = "jfk"
  scope_type = "dcim.site"
  scope_id   = netbox_site.jfk.id
  vid_ranges = [[100, 399]]
}

# same vids at both sites, told apart by site scope
locals {
  dc_vlans = {
    ewr_networking = { site_id = netbox_site.ewr.id, group_id = netbox_vlan_group.ewr.id, group_id = netbox_vlan_group.ewr.id, vid = 100, name = "networking", prefix = "10.1.1.0/24", role_id = netbox_ipam_role.networking.id }
    ewr_mgmt       = { site_id = netbox_site.ewr.id, group_id = netbox_vlan_group.ewr.id, vid = 200, name = "mgmt", prefix = "10.1.2.0/24", role_id = netbox_ipam_role.mgmt.id }
    ewr_compute    = { site_id = netbox_site.ewr.id, group_id = netbox_vlan_group.ewr.id, vid = 300, name = "compute", prefix = "10.1.3.0/24", role_id = netbox_ipam_role.compute.id }
    jfk_networking = { site_id = netbox_site.jfk.id, group_id = netbox_vlan_group.jfk.id, group_id = netbox_vlan_group.jfk.id, vid = 100, name = "networking", prefix = "10.2.1.0/24", role_id = netbox_ipam_role.networking.id }
    jfk_mgmt       = { site_id = netbox_site.jfk.id, group_id = netbox_vlan_group.jfk.id, vid = 200, name = "mgmt", prefix = "10.2.2.0/24", role_id = netbox_ipam_role.mgmt.id }
    jfk_compute    = { site_id = netbox_site.jfk.id, group_id = netbox_vlan_group.jfk.id, vid = 300, name = "compute", prefix = "10.2.3.0/24", role_id = netbox_ipam_role.compute.id }
  }
}

resource "netbox_vlan" "dc" {
  for_each  = local.dc_vlans
  name      = each.value.name
  vid       = each.value.vid
  site_id   = each.value.site_id
  group_id  = each.value.group_id
  role_id   = each.value.role_id
  tenant_id = netbox_tenant.vaulter.id
  status    = "active"
}

resource "netbox_prefix" "dc" {
  for_each  = local.dc_vlans
  prefix    = each.value.prefix
  status    = "active"
  site_id   = each.value.site_id
  vlan_id   = netbox_vlan.dc[each.key].id
  role_id   = each.value.role_id
  tenant_id = netbox_tenant.vaulter.id
}

resource "netbox_ip_address" "compute_gateway" {
  for_each    = { ewr = "10.1.3.1/24", jfk = "10.2.3.1/24" }
  ip_address  = each.value
  status      = "reserved"
  tenant_id   = netbox_tenant.vaulter.id
  description = "default gateway"
}

# marked populated + utilized because the dhcp server owns these, not netbox
resource "netbox_ip_range" "compute_dhcp" {
  for_each = {
    ewr = { start = "10.1.3.2/24", end = "10.1.3.9/24" }
    jfk = { start = "10.2.3.2/24", end = "10.2.3.9/24" }
  }
  start_address  = each.value.start
  end_address    = each.value.end
  status         = "active"
  role_id        = netbox_ipam_role.compute.id
  tenant_id      = netbox_tenant.vaulter.id
  mark_populated = true
  mark_utilized  = true
  description    = "dhcp pool"
}

# ethernet/ocp1/1 arrives with the nic module, ilo from the device type - terraform never sees
# their ids - look them up the same way the power ports are
data "netbox_device_interfaces" "server_nics" {
  name_regex = "^(Ethernet/OCP1/1|iLO)$"
  # ethernet/ocp1/1 only exists once the nic module is installed
  depends_on = [terraform_data.modules]
}

locals {
  server_nics = { for i in data.netbox_device_interfaces.server_nics.interfaces : "${i.device_id}/${i.name}" => i.id }
}

resource "netbox_ip_address" "ewr_server" {
  count               = local.servers_per_rack * 2
  ip_address          = "10.1.3.${10 + count.index}/24"
  device_interface_id = local.server_nics["${netbox_device.ewr_app[count.index].id}/Ethernet/OCP1/1"]
  status              = "active"
  tenant_id           = netbox_tenant.vaulter.id
  dns_name            = "${netbox_device.ewr_app[count.index].name}.ewr.vaulter.net"
}

resource "netbox_ip_address" "ewr_ilo" {
  count               = local.servers_per_rack * 2
  ip_address          = "10.1.2.${10 + count.index}/24"
  device_interface_id = local.server_nics["${netbox_device.ewr_app[count.index].id}/iLO"]
  status              = "active"
  tenant_id           = netbox_tenant.vaulter.id
  dns_name            = "${netbox_device.ewr_app[count.index].name}-ilo.ewr.vaulter.net"
}



resource "netbox_device_primary_ip" "ewr_server" {
  count         = local.servers_per_rack * 2
  device_id     = netbox_device.ewr_app[count.index].id
  ip_address_id = netbox_ip_address.ewr_server[count.index].id
}


# netbox treats the rfcs as pseudo-registries. only rfc1918 applies here - the transit
# /30s are provider-assigned out of zayo/at&t space, so we hold no aggregate for them.
resource "netbox_rir" "rfc1918" {
  name       = "RFC 1918"
  slug       = "rfc1918"
  is_private = true
}

resource "netbox_aggregate" "rfc1918" {
  prefix      = "10.0.0.0/8"
  rir_id      = netbox_rir.rfc1918.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "private address space"
}
