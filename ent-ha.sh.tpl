#!/bin/bash

set -xeuo pipefail

cd /root

# install netbox enterprise
curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/${enterprise_release_channel}" -H "Authorization: ${enterprise_license_id}" -o netbox-enterprise-${enterprise_release_channel}.tgz -s

tar zxvf netbox-enterprise-${enterprise_release_channel}.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${enterprise_console_password} --config-values config.yaml --yes

sleep 360

./netbox-enterprise join print-command > node2.sh
aws s3 cp node2.sh s3://${bucket}/

./netbox-enterprise join print-command > node3.sh
aws s3 cp node3.sh s3://${bucket}/

touch node1.done
aws s3 cp node1.done s3://${bucket}/