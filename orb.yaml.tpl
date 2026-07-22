orb:
  config_manager:
    active: local
  backends:
    common:
      diode:
        #dry_run: True
        #dry_run_output_dir: /opt/orb
        target: $${DIODE_SERVER}
        client_id: $${DIODE_CLIENT_ID}
        client_secret: $${DIODE_CLIENT_SECRET}
        agent_name: orb1
    network_discovery:
    device_discovery:
    snmp_discovery:
    worker:
  secrets_manager:
    active: vault
    sources:
      vault:
        address: "http://VAULTIP:8200"
        auth: token
        auth_args:
          token: "dev-only-token"
  policies:
    network_discovery:
      network_policy:
        config:
        scope:
          targets: 
            - ${public_subnet}
          fast_mode: True
          timing: 5
    device_discovery:
      device_policy:
        config:
        scope:
          - driver: ios
            hostname: ${c8kv_ip}
            username: iosuser
            password: "$${vault://secret/cisco/v8000/password}"
#    snmp_discovery:
#      snmp_policy:
#        config:
#        scope:
#          targets:
#            - host: "${c8kv_ip}"
#          authentication:
#            protocol_version: "SNMPv2c"
#            community: "public"
#    worker:
#      msft_dhcp_worker:
#        config:
#          package: nbl_msft_dhcp
#          MSFT_DHCP_HOST: "${dhcp_ip}"
#          MSFT_DHCP_USERNAME: ".\\svc-netbox"
#          MSFT_DHCP_PASSWORD: "NetBoxDHCP123!"
#          MSFT_DHCP_PORT: 5985
#          MSFT_DHCP_USE_SSL: false
#          MSFT_DHCP_VERIFY_SSL: false
#          BOOTSTRAP: True
#        scope: