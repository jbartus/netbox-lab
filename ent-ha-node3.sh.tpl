#!/bin/bash

set -xeuo pipefail

cd /root

sleep 800

dd if=/dev/zero of=/var/lib/foo bs=1M count=1024
rm -f /var/lib/foo

curl http://${node1_ip}:30001/node3.sh -o node3.sh
sed -i 's/join 10/join --no-ha 10/' node3.sh # to prevent the script from prompting yes/no
chmod +x node3.sh
./node3.sh

./netbox-enterprise enable-ha