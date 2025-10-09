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

cat << 'EOF' > .env
DIODE_CLIENT_ID=
DIODE_CLIENT_SECRET=
EOF

cat << 'EOF' > scan.sh
# cleanup any previous runs
docker stop orb 2>/dev/null || true
docker rm orb 2>/dev/null || true

# run the scan
docker run --env-file .env --net host -d --name orb -v $${PWD}:/opt/orb/ \
  netboxlabs/orb-agent:latest run --config /opt/orb/orb.yaml

# follow the logs
docker logs orb -f
EOF

chmod +x scan.sh

docker run -d -p 8200:8200 -e 'VAULT_DEV_ROOT_TOKEN_ID=dev-only-token' hashicorp/vault
export VAULT_ADDR='http://127.0.0.1:8200'

sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install vault

vault login dev-only-token
vault kv put secret/cisco/v8000 password=Hardcode12345

dnf -y install net-snmp-utils net-snmp-libs