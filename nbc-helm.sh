#!/bin/bash

helm install netbox oci://ghcr.io/netbox-community/netbox-chart/netbox \
  --namespace netbox \
  --create-namespace \
  --set persistence.enabled=false \
  --set postgresql.enabled=false \
  --set externalDatabase.host=$(terraform output -raw postgres_host) \
  --set externalDatabase.password=$(terraform output -raw postgres_password) \

# admin password
kubectl -n netbox get secrets netbox-superuser -o jsonpath="{.data.password}" | base64 --decode

echo # newline
echo "kubectl -n netbox port-forward svc/netbox 8080:80"
