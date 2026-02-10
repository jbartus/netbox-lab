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
%{ if diode_server != "" ~}
DIODE_SERVER=grpc://${diode_server}:80/diode
%{ else ~}
DIODE_SERVER=
%{ endif ~}
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
vault kv put secret/cisco/v8000 password=hardcode

dnf -y install nmap net-snmp-utils net-snmp-libs

# setup a venv and install diode sdk (which requires python >3.10)
dnf install -y python3.12 python3.12-devel
python3.12 -m venv .venv
source .venv/bin/activate
pip install netboxlabs-diode-sdk

# drop a wrapper script for dryrun_replay.py
cat << 'EOF' > replay.sh
#!/bin/bash

set -euo pipefail

# switch to the local venv and python 3.12
source .venv/bin/activate

# load env vars
source .env

# run dryrun_replay.py with the files passed as arguments
python .venv/lib/python3.12/site-packages/netboxlabs/diode/scripts/dryrun_replay.py \
  --app-name agent \
  --app-version 1 \
  --target "$DIODE_SERVER" \
  --client-id "$DIODE_CLIENT_ID" \
  --client-secret "$DIODE_CLIENT_SECRET" \
  "$@"
EOF

chmod +x replay.sh