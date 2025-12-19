kubectl -n netbox-enterprise delete postgrescluster netbox-enterprise-postgres-cluster
helm -n netbox-enterprise uninstall netbox-enterprise
kubectl delete namespace netbox-enterprise
