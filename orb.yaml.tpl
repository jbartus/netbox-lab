orb:
  config_manager:
    active: local
  backends:
    common:
      diode:
        target: grpc://${diode_server}:80/diode
        client_id: $${DIODE_CLIENT_ID}
        client_secret: $${DIODE_CLIENT_SECRET}
        agent_name: orb1
    network_discovery:
    device_discovery:
    snmp_discovery:
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
    snmp_discovery:
      snmp_policy:
        config:
        scope:
          targets:
            - host: "${c8kv_ip}"
          authentication:
            protocol_version: "SNMPv2c"
            community: "public"