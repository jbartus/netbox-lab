#!/bin/bash

set -xeuo pipefail

dnf -y install ansible python3-pip
pip install pynetbox

cd /root

cat << 'EOF' > ansible.cfg
${ansible_cfg}
EOF

cat << 'EOF' > ansible_nb_inv.yaml
${ansible_nb_inv_yaml}
EOF

NETBOX_API=https://${netbox_api}/

echo "export NETBOX_API=$${NETBOX_API}" >> .bash_profile

until [ "$(curl -o /dev/null -sk --max-time 2 -w '%%{http_code}' "$${NETBOX_API}")" -eq 200 ]; do
    sleep 30
done

TOKEN=$(curl "$${NETBOX_API}/api/users/tokens/provision/" -H 'Content-Type: application/json' -d '{"username": "admin", "password": "${admin_password}"}' -sk | jq '.key' -r)

echo "export NETBOX_TOKEN=$${TOKEN}" >> .bash_profile
