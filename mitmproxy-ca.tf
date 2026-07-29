# pre-generate the mitmproxy CA in terraform so both vms share a known CA
# the proxy runs with it and the enterprise box trusts it via the host trust store
resource "tls_private_key" "mitmproxy_ca" {
  count     = var.enable_mitmproxy ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "mitmproxy_ca" {
  count           = var.enable_mitmproxy ? 1 : 0
  private_key_pem = tls_private_key.mitmproxy_ca[0].private_key_pem

  subject {
    common_name  = "mitmproxy"
    organization = "mitmproxy"
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment",
  ]
}
