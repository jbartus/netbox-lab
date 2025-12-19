#!/bin/bash

set -xeuo pipefail

cd /root

# install netbox enterprise
curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/${enterprise_release_channel}" -H "Authorization: ${enterprise_token}" -o netbox-enterprise-${enterprise_release_channel}.tgz -s

tar zxvf netbox-enterprise-${enterprise_release_channel}.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${enterprise_console_password} --config-values config.yaml

# place the custom-objects install script
cat << 'EOF' > enterprise-co.sh
${enterprise_co_sh}
EOF

chmod +x enterprise-co.sh

# make a dummy cert for saml
mkdir saml
openssl req -x509 -newkey rsa -keyout saml/key.pem -out saml/cert.pem -nodes -subj /CN=example.org

# automatically run enterprise shell on login
echo './netbox-enterprise shell' >> /root/.bash_profile

# handy shortcuts
cat << 'EOF' >> /root/.bashrc
alias klogs='kubectl -n kotsadm logs deployment/netbox-enterprise -f'
alias kexec='kubectl -n kotsadm exec deployment/netbox-enterprise -it -- /bin/bash'
EOF

