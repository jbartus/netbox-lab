apiVersion: kots.io/v1beta1
kind: ConfigValues
spec:
  values:
    accept_tos_2024_05_24:
      value: ACCEPT
    superuser_password:
      valuePlaintext: ${enterprise_admin_password}
    replicas:
      value: "1"
    netbox_configuration_py:
      value: |
        AUTH_PASSWORD_VALIDATORS = []
        PLUGINS=[
          "netbox_qrcode",
          "netbox_reorder_rack"
        ]
%{ if proxy_url != "" ~}
        # interim workaround for NBE's empty-lowercase-proxy-env bug
        # NetBox's documented HTTP_PROXIES makes outbound honor the proxy regardless
        HTTP_PROXIES = {"http": "${proxy_url}", "https": "${proxy_url}"}
%{ endif ~}
%{ if ca_cert_pem != "" ~}
    extra_ca_certificates:
      value: |
        ${indent(8, ca_cert_pem)}
%{ endif ~}
