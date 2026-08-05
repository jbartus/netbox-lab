resource "netbox_config_context" "ewr_ntp" {
  name  = "ewr-ntp"
  sites = [netbox_site.ewr.id]
  data = jsonencode({
    ntp_servers = [
      "0.pool.ntp.org",
      "1.pool.ntp.org",
    ]
  })
}

resource "netbox_config_context" "jfk_ntp" {
  name  = "jfk-ntp"
  sites = [netbox_site.jfk.id]
  data = jsonencode({
    ntp_servers = [
      "2.pool.ntp.org",
      "3.pool.ntp.org",
    ]
  })
}

resource "netbox_config_template" "ios_ntp" {
  name          = "ios-ntp"
  template_code = "{% for ntp in ntp_servers %}\nntp server {{ ntp }}\n{% endfor %}"
}
