#!/bin/bash

set -xeuo pipefail

cd /root

curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/stable" -H "Authorization: ${nbe_token}" -o netbox-enterprise-stable.tgz -s

tar zxvf netbox-enterprise-stable.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${nbe_console_password} --config-values config.yaml

dnf -y install docker
systemctl enable --now docker
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose
