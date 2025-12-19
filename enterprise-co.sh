#!/bin/bash

set -xeuo pipefail

mkdir /tmp/wheelhouse

ENTERPRISE_SOURCE_POD="$( \
  kubectl get pods -A \
  -o go-template='{{ range .items }}{{ .metadata.name }}{{ "\n" }}{{ end }}' \
  -l com.netboxlabs.netbox-enterprise/custom-plugins-upload=true \
  --field-selector status.phase=Running \
  | head -n 1 \
)"

kubectl cp -n kotsadm "${ENTERPRISE_SOURCE_POD}:/opt/netbox/constraints.txt" /tmp/wheelhouse/constraints.txt

echo 'netboxlabs-netbox-custom-objects==0.1.0' > /tmp/wheelhouse/requirements.txt

python3 -m venv venv
source venv/bin/activate

pip download \
  --platform="manylinux_2_17_x86_64" \
  --only-binary=":all:" \
  --python-version="3.12" \
  --dest "/tmp/wheelhouse" \
  --find-links "/tmp/wheelhouse" \
  -c /tmp/wheelhouse/constraints.txt \
  -r /tmp/wheelhouse/requirements.txt

tar -C /tmp -czf /tmp/wheelhouse.tar.gz wheelhouse

kubectl cp -n kotsadm /tmp/wheelhouse.tar.gz "${ENTERPRISE_SOURCE_POD}:/opt/netbox/netbox/media/wheelhouse.tar.gz"