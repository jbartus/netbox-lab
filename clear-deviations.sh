#!/bin/bash
set -e

POD=$(kubectl -n kotsadm get pod -o name -l postgres-operator.crunchydata.com/role=master | head -n 1)

for table in change_sets change_sets_deviation_types changes ingestion_logs; do
  kubectl -n kotsadm exec "$POD" -- psql -d diode -a -c "DELETE FROM $table;"
done
