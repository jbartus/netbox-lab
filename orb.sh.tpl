#!/bin/bash

set -xeuo pipefail

%{ if proxy_url != "" ~}
# no route off the vpc, so dnf/pip/aws all go through the proxy. IMDS stays direct.
export http_proxy="${proxy_url}" https_proxy="${proxy_url}" no_proxy="localhost,127.0.0.1,169.254.169.254"

# scan.sh runs later from an interactive shell, which never sees the exports above
cat > /etc/profile.d/proxy.sh << EOF
export http_proxy="${proxy_url}" https_proxy="${proxy_url}"
export HTTP_PROXY="${proxy_url}" HTTPS_PROXY="${proxy_url}"
export no_proxy="localhost,127.0.0.1,169.254.169.254"
export NO_PROXY="localhost,127.0.0.1,169.254.169.254"
EOF

# trust the proxy CA so this host (and dockerd) accept the intercepted TLS
cat > /etc/pki/ca-trust/source/anchors/mitmproxy-ca-cert.pem << 'CACERT'
${ca_cert_pem}
CACERT
update-ca-trust

# must stay ahead of the first dnf -- set -e means a failed install kills userdata
until curl -s -o /dev/null https://quay.io/v2/; do sleep 5; done
%{ endif ~}

dnf -y install docker

%{ if proxy_url != "" ~}
# route dockerd's image pulls through mitmproxy. The daemon ignores shell env,
# so the proxy must be set in a systemd drop-in (set before docker starts).
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=${proxy_url}"
Environment="HTTPS_PROXY=${proxy_url}"
Environment="NO_PROXY=localhost,127.0.0.1,169.254.169.254"
EOF
%{ endif ~}

systemctl enable --now docker

# get the orb pro agent
docker login quay.io -u '${nbl_registry_user}' -p '${nbl_registry_token}'
docker pull quay.io/netboxlabs/orb-agent-pro:latest

cd /root

cat << 'EOF' > orb.yaml
${orb_yaml}
EOF

TOKEN="$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" -s)"
LOCAL_IP="$(curl -H "X-aws-ec2-metadata-token: $${TOKEN}" 'http://169.254.169.254/latest/meta-data/local-ipv4' -s)"
sed -i "s/VAULTIP/$${LOCAL_IP}/" orb.yaml

%{ if proxy_url != "" ~}
# the container sees none of the host's proxy config (that drop-in is dockerd's)
cat << EOF > proxy.env
HTTPS_PROXY=${proxy_url}
HTTP_PROXY=${proxy_url}
NO_PROXY=$${LOCAL_IP},localhost,127.0.0.1,169.254.169.254
DIODE_CERT_FILE=/opt/orb/mitm-ca.pem
EOF

# PWD is the /opt/orb bind mount, so this lands inside the container too
cat << 'CACERT' > mitm-ca.pem
${ca_cert_pem}
CACERT
%{ endif ~}

cat << 'EOF' > scan.sh
# grab the diode credentials the enterprise host published
[ -f .env ] || aws s3 cp "s3://${bucket}/diode.env" .env

# cleanup any previous runs
docker stop orb 2>/dev/null || true
docker rm orb 2>/dev/null || true

# run the scan
docker run --env-file .env \
%{ if proxy_url != "" ~}
  --env-file proxy.env \
%{ endif ~}
  --net host -d --name orb -v $${PWD}:/opt/orb/ \
  quay.io/netboxlabs/orb-agent-pro:latest run --config /opt/orb/orb.yaml

# follow the logs
docker logs orb -f
EOF

chmod +x scan.sh

docker run -d --name vault --cap-add=IPC_LOCK -p 8200:8200 -e 'VAULT_DEV_ROOT_TOKEN_ID=dev-only-token' -e 'SKIP_SETCAP=true' hashicorp/vault

# the container's own cli -- hashicorp's rpm repo serves a gpg key that no longer matches its packages
VAULT="docker exec -e VAULT_TOKEN=dev-only-token -e VAULT_ADDR=http://127.0.0.1:8200 vault vault"
until $VAULT status > /dev/null 2>&1; do sleep 2; done
$VAULT kv put secret/cisco/v8000 password=hardcode
$VAULT kv put secret/arista/ceos password=admin
echo "alias vault='$VAULT'" >> /root/.bashrc

# grafana, prometheus and an otel collector in one container, with the telemetry dashboard as its home page
mkdir -p grafana
cat << 'EOF' > grafana/telemetry.json
${telemetry_dashboard}
EOF
cat << 'EOF' > grafana/dashboards.yaml
apiVersion: 1
providers:
  - name: lab
    type: file
    options:
      path: /otel-lgtm/grafana/conf/provisioning/dashboards/lab
EOF
docker run -d --name lgtm --restart unless-stopped -p 3000:3000 -p 4317:4317 \
  -e GF_PLUGINS_PREINSTALL=netboxlabs-netbox-datasource \
  -e GF_DASHBOARDS_MIN_REFRESH_INTERVAL=1s \
  -e GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/otel-lgtm/grafana/conf/provisioning/dashboards/lab/telemetry.json \
  -v $${PWD}/grafana/telemetry.json:/otel-lgtm/grafana/conf/provisioning/dashboards/lab/telemetry.json:ro \
  -v $${PWD}/grafana/dashboards.yaml:/otel-lgtm/grafana/conf/provisioning/dashboards/lab.yaml:ro \
  grafana/otel-lgtm:0.37.0

%{ if enable_enterprise ~}
# once enterprise publishes its api token, give grafana a netbox data source -- in the background, nbe takes a while
(
  until aws s3 cp --quiet "s3://${bucket}/netbox.env" netbox.env; do sleep 30; done
  . ./netbox.env
  until curl -sf -u admin:admin -H 'Content-Type: application/json' http://localhost:3000/api/datasources -d @- << EOF
{"name": "NetBox", "type": "netboxlabs-netbox-datasource", "access": "proxy",
 "jsonData": {"url": "$NETBOX_API", "tlsSkipVerify": true}, "secureJsonData": {"apiToken": "$NETBOX_TOKEN"}}
EOF
  do sleep 10; done
) > /dev/null 2>&1 &
%{ endif ~}

# telemetry gets its own always-on agent; the discovery one above waits for scan.sh and diode credentials
cat << 'EOF' > telemetry.yaml
${telemetry_yaml}
EOF
docker run -d --name orb-telemetry --restart unless-stopped --net host -v $${PWD}:/opt/orb/ \
  netboxlabs/orb-agent:2.16.0 run --config /opt/orb/telemetry.yaml

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