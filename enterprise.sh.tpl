#!/bin/bash

set -xeuo pipefail

cd /root

%{ if proxy_url != "" ~}
# used by curl, ignored by EC (which needs them passed explicitly as install command args)
export http_proxy="${proxy_url}" https_proxy="${proxy_url}"

# add the tls proxy cert to this hosts trust store
cat > /etc/pki/ca-trust/source/anchors/mitmproxy-ca-cert.pem << 'CACERT'
${ca_cert_pem}
CACERT
update-ca-trust

# wait for mitmproxy to work
until curl -s -o /dev/null https://app.enterprise.netboxlabs.com; do sleep 5; done
%{ endif ~}

# install netbox enterprise
curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/${enterprise_release_channel}" -H "Authorization: ${enterprise_license_id}" -o netbox-enterprise-${enterprise_release_channel}.tgz -s

tar zxvf netbox-enterprise-${enterprise_release_channel}.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install \
  --license license.yaml \
  --admin-console-password ${enterprise_console_password} \
  --config-values config.yaml \
%{ if proxy_url != "" ~}
  --http-proxy ${proxy_url} \
  --https-proxy ${proxy_url} \
%{ endif ~}
  --yes

# place wheelhouse plugin install script
cat << 'EOF' > enterprise-wheelhouse.sh
${enterprise_wh_sh}
EOF

chmod +x enterprise-wheelhouse.sh

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

# diode db flush
cat << 'EOF' >> clear-deviations.sh
${clear_deviations_sh}
EOF

chmod +x clear-deviations.sh