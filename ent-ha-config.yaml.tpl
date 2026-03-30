apiVersion: kots.io/v1beta1
kind: ConfigValues
spec:
  values:
    accept_tos_2024_05_24:
      value: ACCEPT
    superuser_password:
      valuePlaintext: ${admin_password}
    embedded_postgres_enabled:
      value: "0"
    postgres_external_host:
      value: ${netbox_pg_host}
    postgres_external_password:
      value: ${pg_password}
    postgres_external_host_diode:
      value: ${diode_pg_host}
    postgres_external_password_diode:
      value: ${pg_password}
    postgres_external_host_hydra:
      value: ${hydra_pg_host}
    postgres_external_password_hydra:
      value: ${pg_password}
    embedded_file_storage_enabled:
      value: "0"
    s3_storage_bucket_name:
      value: ${s3_bucket_name}
    s3_storage_access_key_id:
      value: ${s3_key_id}
    s3_storage_secret_access_key:
      value: ${s3_access_key}
    s3_storage_endpoint_region:
      value: ${aws_region}