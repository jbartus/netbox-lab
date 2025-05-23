orb:
  config_manager:
    active: local
  backends:
    network_discovery:
    common:
      diode:
        target: grpc://${diode_server}:80/diode
        client_id: FIXME
        client_secret: FIXME
        agent_name: orb1
  policies:
    network_discovery:
      public_subnets:
        config:
        scope:
          targets: 
            - 10.0.1.0/24
