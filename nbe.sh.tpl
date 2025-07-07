#!/bin/bash

set -xeuo pipefail

cd /root

curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/stable" -H "Authorization: ${nbe_token}" -o netbox-enterprise-stable.tgz -s

tar zxvf netbox-enterprise-stable.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${nbe_console_password} --config-values config.yaml

cat << 'EOF' > nbe-co.sh
${nbe_co_sh}
EOF

chmod +x nbe-co.sh