#!/bin/bash

set -xeuo pipefail

dnf -y install docker
systemctl enable --now docker

bash -c "$(curl -sL https://get.containerlab.dev)"

mkdir -p /root/clab
cd /root/clab

# tarball is gitignored, so pull whatever landed in the bucket and tag it flat
aws s3 cp --recursive s3://${bucket}/clab-images/ .
for f in *.tar.xz; do docker import "$f" ceos:latest; done

cat << 'EOF' > topo.clab.yml
${topo_yaml}
EOF

cat << 'EOF' > clab-spine.cfg
${spine_cfg}
EOF

cat << 'EOF' > clab-leaf.cfg
${leaf_cfg}
EOF

containerlab deploy -t topo.clab.yml
