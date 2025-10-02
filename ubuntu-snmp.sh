#!/bin/bash

set -xeuo pipefail

sudo apt update
sudo apt install snmp snmpd -y

sed -i 's/^mibs ://' /etc/snmp/snmp.conf
sed -i 's/^agentaddress  127\.0\.0\.1,\[::1\]//' /etc/snmp/snmpd.conf

sudo systemctl enable snmpd
sudo systemctl start snmpd
