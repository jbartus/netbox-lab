#!/bin/bash

set -xeuo pipefail

cd /root

# install neko
curl -f "https://app.enterprise.netboxlabs.com/embedded/neko/unstable" -H "Authorization: ${neko_license_id}" -o neko-unstable.tgz

tar -xvzf neko-unstable.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./neko install --license license.yaml --admin-console-password ${neko_console_password} --config-values config.yaml

# automatically run enterprise shell on login
echo './neko shell' >> /root/.bash_profile
