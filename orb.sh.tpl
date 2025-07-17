#!/bin/bash

set -xeuo pipefail

dnf -y install docker
systemctl enable --now docker
docker pull netboxlabs/orb-agent:latest

cd /root

cat << 'EOF' > orb.yaml
${orb_yaml}
EOF

TOKEN="$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" -s)"
LOCAL_IP="$(curl -H "X-aws-ec2-metadata-token: $${TOKEN}" 'http://169.254.169.254/latest/meta-data/local-ipv4' -s)"
sed -i "s/VAULTIP/$${LOCAL_IP}/" orb.yaml

cat << 'EOF' > scan.sh
docker run -u root -v /root:/opt/orb/ \
  -e DIODE_CLIENT_ID=$${DIODE_CLIENT_ID} \
  -e DIODE_CLIENT_SECRET=$${DIODE_CLIENT_SECRET} \
  netboxlabs/orb-agent:latest run -c /opt/orb/orb.yaml
EOF

chmod +x scan.sh

docker run -d -p 8200:8200 -e 'VAULT_DEV_ROOT_TOKEN_ID=dev-only-token' hashicorp/vault
export VAULT_ADDR='http://127.0.0.1:8200'

sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install vault

vault login dev-only-token
vault kv put secret/cisco/v8000 password=Hardcode12345
