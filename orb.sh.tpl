#!/bin/bash

set -xeuo pipefail

dnf -y install docker
systemctl enable --now docker
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

docker pull netboxlabs/orb-agent:latest

mkdir /opt/orb
cd /opt/orb

cat << 'EOF' > orb.yaml
${orb_yaml}
EOF

echo "docker run -u root -v /opt/orb:/opt/orb/ netboxlabs/orb-agent:latest run -c /opt/orb/orb.yaml" > /opt/orb/scan.sh
chmod +x /opt/orb/scan.sh