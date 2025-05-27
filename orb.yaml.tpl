orb:
  config_manager:
    active: local
  backends:
    network_discovery:
    common:
      diode:
        target: grpc://${diode_server}:80/diode
        client_id: $${DIODE_CLIENT_ID}
        client_secret: $${DIODE_CLIENT_SECRET}
        agent_name: orb1
  policies:
    network_discovery:
      public_subnets:
        config:
        scope:
          targets: 
            - ${public_subnet}
          fast_mode: True
