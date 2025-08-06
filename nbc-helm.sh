#!/bin/bash

helm install netbox oci://ghcr.io/netbox-community/netbox-chart/netbox \
  --namespace netbox \
  --create-namespace \
  --set persistence.enabled=false \
  --set postgresql.enabled=false \
  --set externalDatabase.host=$(terraform output -raw postgres_host) \
  --set externalDatabase.password=$(terraform output -raw postgres_password) \
  --set valkey.primary.persistence.enabled=false \
  --set valkey.replica.persistence.enabled=false \
  --set superuser.password=admin

echo # newline
echo "kubectl -n netbox port-forward svc/netbox 8080:80"
