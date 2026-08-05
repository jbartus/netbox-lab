resource "netbox_tenant" "vaulter" {
  name        = "Vaulter"
  description = "Vaulter.com - all the bait thats fit to click"
}

resource "netbox_contact_role" "colomgr" {
  name = "Colocation Manager"
}

resource "netbox_contact_role" "officemgr" {
  name = "Office Manager"
}

resource "netbox_contact_role" "support" {
  name = "Support"
}

resource "netbox_contact" "joep" {
  name  = "Joe P."
  email = "joep@165halsey.com"
  phone = "973-555-2501"
}

resource "netbox_contact_assignment" "joep_colomgr" {
  content_type = "dcim.site"
  object_id    = netbox_site.ewr.id
  contact_id   = netbox_contact.joep.id
  role_id      = netbox_contact_role.colomgr.id
}

resource "netbox_contact" "mos" {
  name  = "Mo S."
  email = "mo@hso.com"
  phone = "555-959-5220"
}

resource "netbox_contact_assignment" "mos_jfk" {
  content_type = "dcim.site"
  object_id    = netbox_site.jfk.id
  contact_id   = netbox_contact.mos.id
  role_id      = netbox_contact_role.colomgr.id
}

resource "netbox_contact" "juliaa" {
  name  = "Julia A."
  email = "frontdesk@vaulter.com"
}

resource "netbox_contact_assignment" "juliaa_hq" {
  content_type = "dcim.site"
  object_id    = netbox_site.hq.id
  contact_id   = netbox_contact.juliaa.id
  role_id      = netbox_contact_role.officemgr.id
}

resource "netbox_contact" "cogent_support" {
  name  = "Cogent Customer Support"
  email = "support@cogentco.com"
  phone = "877-726-4368"
}

resource "netbox_contact_assignment" "cogent_support" {
  content_type = "circuits.provider"
  object_id    = netbox_circuit_provider.cogent.id
  contact_id   = netbox_contact.cogent_support.id
  role_id      = netbox_contact_role.support.id
}

resource "netbox_contact" "comcast_support" {
  name  = "Comcast Business Customer Support"
  phone = "800-391-3000"
  link  = "https://business.comcast.com/support"
}

resource "netbox_contact_assignment" "comcast_support" {
  content_type = "circuits.provider"
  object_id    = netbox_circuit_provider.comcast.id
  contact_id   = netbox_contact.comcast_support.id
  role_id      = netbox_contact_role.support.id
}

resource "netbox_contact" "zayo_support" {
  name  = "Zayo Customer Support"
  email = "support@zayo.com"
  phone = "866-236-2824"
}

resource "netbox_contact_assignment" "zayo_support" {
  content_type = "circuits.provider"
  object_id    = netbox_circuit_provider.zayo.id
  contact_id   = netbox_contact.zayo_support.id
  role_id      = netbox_contact_role.support.id
}

resource "netbox_contact" "att_support" {
  name  = "AT&T Business Customer Support"
  phone = "800-321-2000"
  link  = "https://www.business.att.com/support/"
}

resource "netbox_contact_assignment" "att_support" {
  content_type = "circuits.provider"
  object_id    = netbox_circuit_provider.att.id
  contact_id   = netbox_contact.att_support.id
  role_id      = netbox_contact_role.support.id
}
