#!/bin/bash

set -xeuo pipefail

cd /root

sleep 700

dd if=/dev/zero of=/var/lib/foo bs=1M count=1024
rm -f /var/lib/foo

curl http://${node1_ip}:30001/node2.sh -o node2.sh
chmod +x node2.sh
./node2.sh