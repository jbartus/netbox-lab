#!/bin/bash

set -xeuo pipefail

cd /root

# wait for the previous node in the chain to finish
until aws s3 cp s3://${bucket}/${wait_for} .; do sleep 15; done

# get the join command from the s3 bucket
aws s3 cp s3://${bucket}/${node}.sh join.sh

# add a --yes to prevent the prompt hanging the script
sed -i '/netbox-enterprise join /s/$/ --yes/' join.sh
chmod +x join.sh
./join.sh

# signal the next node to go
touch ${node}.done
aws s3 cp ${node}.done s3://${bucket}/
