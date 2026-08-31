#!/bin/bash

set -xeuo pipefail

cd /root

curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/ignored" -H "Authorization: ${enterprise_license_id}" -o netbox-enterprise.tgz -s

tar zxvf netbox-enterprise.tgz

# hidden --s3-* flags skip the store prompts; the backup-pick and add-nodes prompts
# ignore --yes and can't be piped, so restore stays a hands-on run
cat << 'EOF' > restore.sh
#!/bin/bash
set -euo pipefail
cd /root
./netbox-enterprise restore \
  --s3-endpoint https://s3.${region}.amazonaws.com \
  --s3-region ${region} \
  --s3-bucket ${bucket} \
  --s3-prefix nbe-backups \
  --s3-access-key-id ${access_key_id} \
  --s3-secret-access-key ${secret_access_key} \
  --yes
EOF

chmod +x restore.sh

echo 'echo "run /root/restore.sh to restore the latest backup"' >> /root/.bash_profile
