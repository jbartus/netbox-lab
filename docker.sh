#!/bin/bash

set -xeuo pipefail

dnf -y install git docker
systemctl enable --now docker

mkdir -p /usr/local/lib/docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

cd /root
git clone -b release https://github.com/netbox-community/netbox-docker.git
cd netbox-docker

cp docker-compose.override.yml.example docker-compose.override.yml
sed -i 's/^    # environment:/    environment:/' docker-compose.override.yml
sed -i 's/^      # SKIP_SUPERUSER: "false"/      SKIP_SUPERUSER: "false"/' docker-compose.override.yml

docker compose pull
docker compose up -d