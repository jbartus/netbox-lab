#!/bin/bash

set -xeuo pipefail

dnf -y install ansible python3-pip java-17-amazon-corretto-headless
pip install pynetbox ansible-rulebook ansible-pylibssh
ansible-galaxy collection install netbox.netbox --upgrade
ansible-galaxy collection install ansible.eda --upgrade

cd /root

cat << 'EOF' > ansible.cfg
[defaults]
inventory = ./ansible_nb_inv.yaml
host_key_checking = False
EOF

cat << 'EOF' > ansible_nb_inv.yaml
plugin: netbox.netbox.nb_inventory
validate_certs: False
device_query_filters:
  - manufacturer: cisco
  - platform: ios
EOF

cat << 'EOF' > ansible-in.yaml
${ansible_in_yaml}
EOF

echo 'ansible-playbook -i localhost, ansible-in.yaml' > example-input.sh
chmod +x example-input.sh

cat << 'EOF' > rulebook.yaml
${rulebook_yaml}
EOF

cat << 'EOF' > int-desc.yaml
${int_desc_yaml}
EOF

echo ${c8kv_ip} > inventory

cat << 'EOF' > /etc/systemd/system/ansible-rulebook.service
[Unit]
Description=Ansible Rulebook

[Service]
EnvironmentFile=-/root/netbox.env
ExecStart=/usr/local/bin/ansible-rulebook --rulebook /root/rulebook.yaml -i /root/inventory -vvv
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ansible-rulebook

%{ if enable_enterprise ~}
# wait for the enterprise host to publish its admin api token, then hand it to playbooks and the rulebook
until aws s3 cp "s3://${bucket}/netbox.env" /root/netbox.env; do sleep 30; done
echo 'set -a; . /root/netbox.env; set +a' >> /root/.bashrc
systemctl restart ansible-rulebook
%{ endif ~}