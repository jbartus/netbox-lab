#!/bin/bash

helm install netbox oci://ghcr.io/netbox-community/netbox-chart/netbox \
  --namespace netbox \
  --create-namespace \
  --set persistence.enabled=false \
  --set postgresql.enabled=false \
  --set externalDatabase.host=$(terraform output -raw postgres_host) \
  --set externalDatabase.password=$(terraform output -raw postgres_password) \
  --set valkey.enabled=false \
  --set tasksDatabase.host=$(terraform output -raw redis_host) \
  --set cachingDatabase.host=$(terraform output -raw redis_host)

kubectl -n netbox create secret generic netbox-valkey \
  --from-literal=cache_password="" \
  --from-literal=task_password=""

# admin password
kubectl -n netbox get secrets netbox-superuser -o jsonpath="{.data.password}" | base64 --decode

# port forward
# kubectl -n netbox port-forward svc/netbox 8080:80

# cleanup
# helm -n netbox uninstall netbox
