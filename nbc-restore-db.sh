#!/usr/bin/env bash

set -euo pipefail

ORG_ID=""
TARGET_NB_ID=""
BACKUP_ID=""
API_KEY=""

# retrieve the backup
retrieval_id=$(curl -sS --fail-with-body "https://api.netboxlabs.com/v2/organization/${ORG_ID}/backup-retrieved/" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"backup_id\":\"${BACKUP_ID}\"}" | jq -r '.id')

# wait until its retrieved
until url=$(curl -sS --fail-with-body "https://api.netboxlabs.com/v2/organization/${ORG_ID}/backup-retrieved/" \
             -H "Authorization: Bearer ${API_KEY}" \
             | jq -r --arg id "$retrieval_id" '.data[] | select(.id==$id) | .presigned_url // empty')
      [ -n "$url" ]
do
  sleep 2
done

# restore the backup
curl -sS --fail-with-body "https://api.netboxlabs.com/v2/organization/${ORG_ID}/backup-restore/" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"retrieval_id\":\"${retrieval_id}\",\"target_nb_id\":\"${TARGET_NB_ID}\"}"
