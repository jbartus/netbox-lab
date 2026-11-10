#!/bin/bash

set -xeuo pipefail

dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
dnf install -y ansible-core unzip jq

curl -sSo /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# the containerized installer runs rootless podman as a regular user, which needs a lingering systemd user session
EC2_UID=$(id -u ec2-user)
loginctl enable-linger ec2-user
until [ -S /run/user/$EC2_UID/bus ]; do sleep 2; done

cd /home/ec2-user
/usr/local/bin/aws s3 cp "s3://${bucket}/${installer}.tar" .
tar -xf ${installer}.tar

# growth topology on one host, minus hub and metrics
HOST=$(hostname -f)
cat << EOF > ${installer}/inventory-lab
[automationgateway]
$HOST

[automationcontroller]
$HOST

[automationeda]
$HOST

[database]
$HOST

EOF

cat << 'EOF' >> ${installer}/inventory-lab
[all:vars]
ansible_connection=local
postgresql_admin_username=postgres
postgresql_admin_password=${admin_password}
registry_username=${registry_user}
registry_password=${registry_token}
redis_mode=standalone
automationmetrics_skip_install=true
gateway_admin_password=${admin_password}
gateway_pg_password=${admin_password}
controller_admin_password=${admin_password}
controller_pg_password=${admin_password}
controller_percent_memory_capacity=0.5
eda_admin_password=${admin_password}
eda_pg_password=${admin_password}
EOF

for svc in gateway controller eda; do echo "$${svc}_pg_host=$HOST" >> ${installer}/inventory-lab; done

chown -R ec2-user: /home/ec2-user/${installer}
sudo -iu ec2-user env XDG_RUNTIME_DIR=/run/user/$EC2_UID \
  bash -c "cd ${installer} && ansible-playbook -i inventory-lab ansible.containerized_installer.install"

API=https://localhost/api/controller/v2
curl -fsSk -u 'admin:${admin_password}' -H 'Content-Type: application/json' -X POST $API/config/subscriptions/ \
  -d '{"subscriptions_client_id": "${rh_client_id}", "subscriptions_client_secret": "${rh_client_secret}"}' > /root/rh-subscriptions.json
SUB_ID=$(jq -r '[.[] | select(.product_name | test("Ansible Automation Platform"))][0].subscription_id' /root/rh-subscriptions.json)
curl -fsSk -u 'admin:${admin_password}' -H 'Content-Type: application/json' -X POST $API/config/attach/ \
  -d "{\"subscription_id\": \"$SUB_ID\"}"
