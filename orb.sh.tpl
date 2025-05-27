#!/bin/bash

set -xeuo pipefail

dnf -y install docker
systemctl enable --now docker
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

docker pull netboxlabs/orb-agent:latest

cd /root

cat << 'EOF' > orb.yaml
${orb_yaml}
EOF

cat << 'EOF' > scan.sh
docker run -u root -v /root:/opt/orb/ \
  -e DIODE_CLIENT_ID=$${DIODE_CLIENT_ID} \
  -e DIODE_CLIENT_SECRET=$${DIODE_CLIENT_SECRET} \
  netboxlabs/orb-agent:latest run -c /opt/orb/orb.yaml
EOF

chmod +x scan.sh