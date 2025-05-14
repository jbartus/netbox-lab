apiVersion: kots.io/v1beta1
kind: ConfigValues
spec:
  values:
    accept_tos_2024_05_24:
      value: ACCEPT
    superuser_password:
      valuePlaintext: ${nbe_admin_password}
