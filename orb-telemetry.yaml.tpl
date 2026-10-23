orb:
  config_manager:
    active: local
  backends:
    common:
      otlp:
        grpc: "grpc://127.0.0.1:4317"
    # the c8kv has no gnmi server, so it's polled over the snmp it already has
    snmp_telemetry:
%{ if enable_clab ~}
    gnmi_telemetry:
      otel_export_period: 1
%{ endif ~}
  policies:
    snmp_telemetry:
      c8kv:
        config:
          metrics_interval: 60
        scope:
          targets:
            - host: "${c8kv_ip}"
          authentication:
            protocol_version: "v2c"
            community: "public"
%{ if enable_clab ~}
    gnmi_telemetry:
      arista:
        config:
          metrics_interval: 1
        scope:
          username: admin
          password: admin
          port: 6030
          tls:
            insecure: true
          # listed one by one: a range is swept once at start, before clab is up, and never again
          targets:
            - host: 172.20.20.11
            - host: 172.20.20.12
            - host: 172.20.20.13
            - host: 172.20.20.14
%{ endif ~}
