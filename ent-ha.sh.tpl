#!/bin/bash

set -xeuo pipefail

cd /root

# install netbox enterprise
curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/${enterprise_release_channel}" -H "Authorization: ${enterprise_license_id}" -o netbox-enterprise-${enterprise_release_channel}.tgz -s

tar zxvf netbox-enterprise-${enterprise_release_channel}.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${enterprise_console_password} --config-values config.yaml

sleep 360

mkdir joincmds
./netbox-enterprise join print-command > joincmds/node2.sh
./netbox-enterprise join print-command > joincmds/node3.sh
cd joincmds
nohup python3 -m http.server 30001 &>/dev/null &