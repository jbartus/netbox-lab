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
          "netbox_topology_views",
          "netbox_floorplan",
          "netbox_dns",
          "netbox_qrcode",
          "netbox_reorder_rack"
        ]

        #PLUGINS_CONFIG = {
        #  'netbox_changes': {
        #    'protect_main': True
        #  },
        #  'netbox_branching': {
        #    'merge_validators': ['netbox_changes.validators.change_request_approved']
        #  }
        #}


