#!/bin/bash

helm install nbc oci://ghcr.io/netbox-community/netbox-chart/netbox --namespace nbc --create-namespace

# sleep 400
#export POD_NAME=$(kubectl get pods --namespace "nbc" -l "app.kubernetes.io/name=netbox,app.kubernetes.io/instance=nbc" -o jsonpath="{.items[0].metadata.name}")
#kubectl port-forward $POD_NAME 8080:8080 -n nbc

# cleanup
# helm -n nbc uninstall nbc
# kubectl delete pvc -n nbc --all