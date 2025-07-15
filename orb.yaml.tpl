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
  policies:
    network_discovery:
      public_subnets:
        config:
        scope:
          targets: 
            - ${public_subnet}
          fast_mode: True
          timing: 5
    device_discovery:
      c8kv_instances:
        config:
        scope:
          - driver: ios
            hostname: ${c8kv_ip}
            username: iosuser
            password: $${C8KV_PASS}