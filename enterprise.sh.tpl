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
# note: the channel segment in the url is ignored, only the server-side setting matters
curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/ignored" -H "Authorization: ${enterprise_license_id}" -o netbox-enterprise.tgz -s

tar zxvf netbox-enterprise.tgz

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

%{ if enable_discovery ~}
# mint a diode ingest credential and publish it to s3 for the orb host to fetch
# this is the same call the Client Credentials > Add button makes in the web ui
cat << 'EOF' > mint-diode-creds.py
from netbox_diode_plugin.client import create_client
creds = create_client(None, "orb1", "diode:ingest")
print("CLIENT_ID", creds["client_id"])
print("CLIENT_SECRET", creds["client_secret"])
EOF

# retry until netbox is up and diode's hydra is actually issuing tokens -- the
# deployments report Available well before that. manage.py shell mixes a startup
# banner into stdout, so keep the whole thing and pick the two lines we want out
export KUBECONFIG=/var/lib/embedded-cluster/k0s/pki/admin.conf
export PATH=/var/lib/embedded-cluster/bin:$PATH
until MINT_OUTPUT=$(kubectl exec -i -n kotsadm deploy/netbox-netbox -c netbox -- /opt/netbox/netbox/manage.py shell < mint-diode-creds.py); do sleep 30; done
CLIENT_ID=$(awk '/^CLIENT_ID/ {print $2}' <<< "$MINT_OUTPUT")
CLIENT_SECRET=$(awk '/^CLIENT_SECRET/ {print $2}' <<< "$MINT_OUTPUT")
NBE_IP=$(hostname -I | awk '{print $1}')

# the orb host's scan.sh downloads this as its .env
cat << EOF > diode.env
DIODE_SERVER=grpc://$NBE_IP:80/diode
DIODE_CLIENT_ID=$CLIENT_ID
DIODE_CLIENT_SECRET=$CLIENT_SECRET
EOF

aws s3 cp diode.env "s3://${bucket}/diode.env"
%{ endif ~}