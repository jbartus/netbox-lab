#!/bin/bash

set -xeuo pipefail

cd /root

curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/${nbe_release_channel}" -H "Authorization: ${nbe_token}" -o netbox-enterprise-${nbe_release_channel}.tgz -s

tar zxvf netbox-enterprise-${nbe_release_channel}.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${nbe_console_password} --config-values config.yaml

cat << 'EOF' > nbe-co.sh
${nbe_co_sh}
EOF

chmod +x nbe-co.sh

mkdir saml
openssl req -x509 -newkey rsa -keyout saml/key.pem -out saml/cert.pem -nodes -subj /CN=example.org