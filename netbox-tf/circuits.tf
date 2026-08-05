resource "netbox_circuit_provider" "cogent" {
  name = "Cogent"
}

resource "netbox_circuit_provider" "comcast" {
  name = "Comcast"
}

resource "netbox_circuit_provider" "zayo" {
  name = "Zayo"
}

resource "netbox_circuit_provider" "att" {
  name = "AT&T"
}

resource "netbox_circuit_type" "epl" {
  name = "Ethernet Private Line"
  slug = "epl"
}

resource "netbox_circuit_type" "internet" {
  name = "Internet"
  slug = "internet"
}

resource "netbox_circuit" "ewr_jfk" {
  cid         = "1-300123456"
  description = "ewr<->jfk"
  provider_id = netbox_circuit_provider.cogent.id
  type_id     = netbox_circuit_type.epl.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "ewr_jfk_a" {
  circuit_id = netbox_circuit.ewr_jfk.id
  term_side  = "A"
  site_id    = netbox_site.ewr.id
  port_speed = 10000000
}

resource "netbox_circuit_termination" "ewr_jfk_z" {
  circuit_id = netbox_circuit.ewr_jfk.id
  term_side  = "Z"
  site_id    = netbox_site.jfk.id
  port_speed = 10000000
}

resource "netbox_circuit" "ewr_internet" {
  cid         = "OGKR/123456//ZYO"
  description = "165 halsey internet"
  provider_id = netbox_circuit_provider.zayo.id
  type_id     = netbox_circuit_type.internet.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "ewr_internet_a" {
  circuit_id = netbox_circuit.ewr_internet.id
  term_side  = "A"
  site_id    = netbox_site.ewr.id
  port_speed = 1000000
}

resource "netbox_circuit" "jfk_internet" {
  cid         = "ASE-4821637-NY"
  description = "375 pearl internet"
  provider_id = netbox_circuit_provider.att.id
  type_id     = netbox_circuit_type.internet.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "jfk_internet_a" {
  circuit_id = netbox_circuit.jfk_internet.id
  term_side  = "A"
  site_id    = netbox_site.jfk.id
  port_speed = 1000000
}

resource "netbox_circuit" "hq_internet" {
  cid         = "12.KQGS.487213"
  description = "hq internet"
  provider_id = netbox_circuit_provider.comcast.id
  type_id     = netbox_circuit_type.internet.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "hq_internet_a" {
  circuit_id = netbox_circuit.hq_internet.id
  term_side  = "A"
  site_id    = netbox_site.hq.id
  port_speed = 500000
}
