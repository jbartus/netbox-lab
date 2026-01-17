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

mkdir group_vars
cat << 'EOF' > group_vars/all.yaml
---
ansible_user: iosuser
ansible_password: Hardcode12345
ansible_become: yes
ansible_become_method: enable
ansible_network_os: cisco.ios.ios
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
# /etc/systemd/system/ansible-rulebook.service
[Unit]
Description=Ansible Rulebook

[Service]
ExecStart=/usr/local/bin/ansible-rulebook --rulebook /root/rulebook.yaml -i /root/inventory --verbose
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ansible-rulebook