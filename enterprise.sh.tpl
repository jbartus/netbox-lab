#!/bin/bash

set -xeuo pipefail

cd /root

%{ if proxy_url != "" ~}
# used by curl, ignored by EC (which needs them passed explicitly as install command args)
# no_proxy or IMDS gets proxied and answers with mitmproxy's identity
export http_proxy="${proxy_url}" https_proxy="${proxy_url}"
export no_proxy="localhost,127.0.0.1,169.254.169.254" NO_PROXY="localhost,127.0.0.1,169.254.169.254"

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

# point disaster recovery at s3 -- what the console's backup settings form does, via the kotsadm pod's /kots
until ./netbox-enterprise shell -c "kubectl exec -n kotsadm deploy/kotsadm -- /kots velero configure-aws-s3 access-key \
  --namespace kotsadm \
  --bucket ${bucket} \
  --path nbe-backups \
  --region ${region} \
  --access-key-id ${access_key_id} \
  --secret-access-key ${secret_access_key}"; do sleep 30; done

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
# the orb host's scan.sh downloads this as its .env
# (with the proxy, TLS by name -- mitmproxy needs a name to mint a cert for)
cat << EOF > diode.env
%{ if proxy_url != "" ~}
DIODE_SERVER=grpcs://$(hostname -f):443/diode
%{ else ~}
DIODE_SERVER=grpc://$(hostname -I | awk '{print $1}'):80/diode
%{ endif ~}
DIODE_CLIENT_ID=$CLIENT_ID
DIODE_CLIENT_SECRET=$CLIENT_SECRET
EOF

aws s3 cp diode.env "s3://${bucket}/diode.env"
%{ endif ~}

# admin api token for post-install setup -- retry until netbox answers
dnf -y install jq
until RESP=$(curl -skf -X POST https://localhost/api/users/tokens/provision/ \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"${enterprise_admin_password}"}'); do sleep 30; done
TOKEN="nbt_$(jq -r .key <<< "$RESP").$(jq -r .token <<< "$RESP")"
nb() { curl -skf -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' "https://localhost/api/$1" -d "$2"; }

# change management policy: one admin approval required to merge a branch
POLICY_ID=$(nb plugins/changes/policies/ '{"name": "require-approval"}' | jq -r .id)
nb plugins/changes/policy-rules/ "{\"policy\": $POLICY_ID, \"name\": \"at-least-one-admin\", \"min_reviews\": 1, \"reviewers\": [$(jq -r .user.id <<< "$RESP")]}"

%{ if enable_ansible ~}
# gi1 description changes on main (incl. branch merges, via EVENTS_PIPELINE) get pushed to the c8kv by the ansible rulebook
WEBHOOK_ID=$(nb extras/webhooks/ '{"name": "ansible-eda", "payload_url": "http://${ansible_ip}:5000/endpoint",
  "http_method": "POST", "http_content_type": "application/json"}' | jq -r .id)
nb extras/event-rules/ '{"name": "gi1-desc-to-ansible", "object_types": ["dcim.interface"], "event_types": ["object_updated"],
  "conditions": {"and": [{"attr": "name", "value": "GigabitEthernet1"}, {"attr": "active_branch", "value": null}]},
  "action_type": "webhook", "action_object_type": "extras.webhook", "action_object_id": '"$WEBHOOK_ID"'}'

# hand the api token to the ansible host, which waits for this file
cat << EOF > netbox.env
NETBOX_API=https://$(hostname -I | awk '{print $1}')/
NETBOX_TOKEN=$TOKEN
EOF
aws s3 cp netbox.env "s3://${bucket}/netbox.env"
%{ endif ~}

%{ if enable_msft_dns_dhcp ~}
# pre-populate the msft dhcp & dns discovery integrations's custom fields so we dont have to do the bootstrap round
nb extras/custom-fields/ '[
  {"name": "msft_dns_additional_names", "type": "json", "object_types": ["ipam.ipaddress"], "ui_editable": "no",
   "label": "Microsoft DNS Additional Names", "description": "Additional DNS names pointing to this IP address"},
  {"name": "dhcp_server", "type": "text", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "DHCP Server", "description": "Source DHCP server hostname or IP that this scope was synced from"},
  {"name": "msft_dhcp_scope_name", "type": "text", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "MS DHCP Scope Name", "description": "Microsoft DHCP scope display name"},
  {"name": "msft_dhcp_scope_state", "type": "text", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "MS DHCP Scope State", "description": "Microsoft DHCP scope state (e.g. Active, Inactive)"},
  {"name": "msft_dhcp_scope_start_range", "type": "text", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "MS DHCP Scope Start Range", "description": "First address in the Microsoft DHCP scope range"},
  {"name": "msft_dhcp_scope_end_range", "type": "text", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "MS DHCP Scope End Range", "description": "Last address in the Microsoft DHCP scope range"},
  {"name": "msft_dhcp_lease_duration_seconds", "type": "integer", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "MS DHCP Lease Duration (seconds)", "description": "Microsoft DHCP scope lease duration in seconds"},
  {"name": "msft_dhcp_options", "type": "json", "object_types": ["ipam.prefix"], "ui_editable": "no",
   "label": "MS DHCP Options", "description": "Microsoft DHCP scope-level option values as reported by Get-DhcpServerv4OptionValue. List of objects with OptionId, Name, Type, Value."}
]'
%{ endif ~}