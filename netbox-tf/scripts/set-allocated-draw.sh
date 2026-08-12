#!/usr/bin/env bash
# Set allocated draw on every power port that came from a module.
#
#   WATTS    per-port allocated draw
#   DEVICES  space separated device ids
set -euo pipefail

for device in $DEVICES; do
  ports=$(curl -sS --fail-with-body -H "Authorization: Token $NETBOX_TOKEN" \
    "$NETBOX_URL/api/dcim/power-ports/?device_id=$device")

  for port in $(jq -r '.results[] | select(.module != null) | .id' <<<"$ports"); do
    curl -sS --fail-with-body -X PATCH "$NETBOX_URL/api/dcim/power-ports/$port/" \
      -H "Authorization: Token $NETBOX_TOKEN" -H "Content-Type: application/json" \
      -d "{\"allocated_draw\":$WATTS}" >/dev/null
  done
done
