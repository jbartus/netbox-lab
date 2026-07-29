#!/bin/bash
set -xeuo pipefail

# install + start docker
dnf install -y docker
systemctl enable --now docker

# supply the terraform-generated CA so mitmproxy intercepts TLS with a CA the
# enterprise box already trusts (via its host trust store). mitmproxy uses this
# instead of generating its own and derives the -cert.pem variants from it.
mkdir -p /root/.mitmproxy
cat > /root/.mitmproxy/mitmproxy-ca.pem << 'EOF'
${ca_pem}
EOF
chmod 777 /root/.mitmproxy            # container runs as non-root uid
chmod 644 /root/.mitmproxy/mitmproxy-ca.pem

docker run -d --name mitmproxy --restart unless-stopped \
  -p 8080:8080 \
  -v /root/.mitmproxy:/home/mitmproxy/.mitmproxy \
  mitmproxy/mitmproxy \
  mitmdump --listen-host 0.0.0.0 --set block_global=false \
  --proxyauth testuser:passw0rd
