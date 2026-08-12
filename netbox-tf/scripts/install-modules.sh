#!/usr/bin/env bash
# Install a module (psu, nic, whatever) into every empty matching bay on a set of devices.
#
# Module bays come from the device type template, so terraform never learns their ids and
# the provider has no data source for them - hence doing this over the API.
#
#   PART     module type part number, e.g. P38995-B21
#   BAYS     bay names, one per line, e.g. "PSU1\nPSU2"
#   DEVICES  space separated device ids
#
# One device at a time on purpose: bulk calls return 2xx having silently skipped a few.
set -euo pipefail

api="$NETBOX_URL/api/dcim"
auth="Authorization: Token $NETBOX_TOKEN"

# the part number is the same for every device, so look the module type up once
type=$(curl -sS --fail-with-body -H "$auth" "$api/module-types/?part_number=$PART" | jq -e '.results[0].id')

for device in $DEVICES; do
  while read -r bay; do
    # -G/--data-urlencode because bay names can contain spaces, e.g. "Power Supply 0"
    bay_id=$(curl -sS --fail-with-body -G -H "$auth" "$api/module-bays/" \
      --data-urlencode "device_id=$device" --data-urlencode "name=$bay" \
      | jq -r '.results[] | select(.installed_module == null) | .id')

    # already filled, so this is a re-run - leave it alone
    [ -n "$bay_id" ] || continue

    curl -sS --fail-with-body -X POST "$api/modules/" -H "$auth" -H "Content-Type: application/json" \
      -d "{\"device\":$device,\"module_bay\":$bay_id,\"module_type\":$type,\"status\":\"active\"}" >/dev/null
  done <<<"$BAYS"
done
