#!/bin/bash

set -xeuo pipefail

cd /root

sleep 700

curl http://${node1_ip}:30001/node2.sh -o node2.sh
sed -i 's/join 10/join --no-ha 10/' node2.sh
chmod +x node2.sh
./node2.sh