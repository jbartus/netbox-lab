#!/bin/bash

helm install netbox-enterprise oci://registry.enterprise.netboxlabs.com/netbox-enterprise/stable/netbox-enterprise \
  --namespace netbox-enterprise \
  --create-namespace \
  --set global.license.id=$(grep nbe_token terraform.tfvars | awk '{print $3}' | sed 's/\"//g') \
  --values nbe-values.yaml \
  --version 1.11.4

kubectl -n netbox-enterprise wait --for=condition=Ready pod -l app.kubernetes.io/name=netbox,app.kubernetes.io/component=netbox --timeout=10m

kubectl -n netbox-enterprise get secret netbox-enterprise-secret-config -o jsonpath="{.data.password}" | base64 --decode

echo # newline
echo "kubectl port-forward -n netbox-enterprise svc/netbox-enterprise 8080:80"
