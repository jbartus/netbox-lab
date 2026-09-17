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

%{ if enable_msft_dns_dhcp ~}
# pre-populate the msft dhcp & dns discovery integrations's custom fields so we dont have to do the bootstrap round
cat << 'EOF' > msft-custom-fields.py
from extras.models import CustomField

# whatever the m2m points at on this release -- ContentType or core.ObjectType
OT = CustomField._meta.get_field("object_types").related_model

FIELDS = [
    ("msft_dns_additional_names", "json", "ipaddress", "Microsoft DNS Additional Names",
     "Additional DNS names pointing to this IP address"),
    ("dhcp_server", "text", "prefix", "DHCP Server",
     "Source DHCP server hostname or IP that this scope was synced from"),
    ("msft_dhcp_scope_name", "text", "prefix", "MS DHCP Scope Name",
     "Microsoft DHCP scope display name"),
    ("msft_dhcp_scope_state", "text", "prefix", "MS DHCP Scope State",
     "Microsoft DHCP scope state (e.g. Active, Inactive)"),
    ("msft_dhcp_scope_start_range", "text", "prefix", "MS DHCP Scope Start Range",
     "First address in the Microsoft DHCP scope range"),
    ("msft_dhcp_scope_end_range", "text", "prefix", "MS DHCP Scope End Range",
     "Last address in the Microsoft DHCP scope range"),
    ("msft_dhcp_lease_duration_seconds", "integer", "prefix", "MS DHCP Lease Duration (seconds)",
     "Microsoft DHCP scope lease duration in seconds"),
    ("msft_dhcp_options", "json", "prefix", "MS DHCP Options",
     "Microsoft DHCP scope-level option values as reported by Get-DhcpServerv4OptionValue. "
     "List of objects with OptionId, Name, Type, Value."),
]

for name, cf_type, model, label, description in FIELDS:
    cf, _ = CustomField.objects.update_or_create(
        name=name,
        defaults={
            "type": cf_type,
            "label": label,
            "description": description,
            "required": False,
            "ui_editable": "no",
        },
    )
    cf.object_types.set([OT.objects.get(app_label="ipam", model=model)])
    print("CUSTOM_FIELD", cf.name)
EOF

export KUBECONFIG=/var/lib/embedded-cluster/k0s/pki/admin.conf
export PATH=/var/lib/embedded-cluster/bin:$PATH
until kubectl exec -i -n kotsadm deploy/netbox-netbox -c netbox -- /opt/netbox/netbox/manage.py shell < msft-custom-fields.py; do sleep 30; done
%{ endif ~}