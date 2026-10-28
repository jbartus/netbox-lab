#!/bin/bash

set -xeuo pipefail

cd /root

# install netbox enterprise
# note: the channel segment in the url is ignored, only the server-side setting matters
curl -f "https://app.enterprise.netboxlabs.com/embedded/netbox-enterprise/ignored" -H "Authorization: ${enterprise_license_id}" -o netbox-enterprise.tgz -s

tar zxvf netbox-enterprise.tgz

cat << 'EOF' > config.yaml
${config_yaml}
EOF

./netbox-enterprise install --license license.yaml --admin-console-password ${enterprise_console_password} --config-values config.yaml --yes

# wait for nbe to finish its first deploy. the cr doesn't exist for the first minute or two, so loop
until ./netbox-enterprise shell -c "kubectl -n kotsadm wait netboxenterprise --all --for=condition=Ready"; do sleep 10; done

# pause the nbe operator while nodes join. it scales postgres/redis/diode the moment a node object
# appears, before that node can take pods, which piles the new replicas onto whichever nodes are ready
./netbox-enterprise shell -c "kubectl -n kotsadm scale deploy/netbox-enterprise --replicas=0"

./netbox-enterprise join print-command > node2.sh
aws s3 cp node2.sh s3://${bucket}/

./netbox-enterprise join print-command > node3.sh
aws s3 cp node3.sh s3://${bucket}/

touch node1.done
aws s3 cp node1.done s3://${bucket}/

# once node3 has joined and every node is ready, resume the operator, then switch file storage to in-cluster (garage) -- what the console's config form does, via the kotsadm pod's /kots
until aws s3 cp s3://${bucket}/node3.done .; do sleep 15; done
./netbox-enterprise shell -c "kubectl wait nodes --all --for=condition=Ready --timeout=10m"
./netbox-enterprise shell -c "kubectl -n kotsadm scale deploy/netbox-enterprise --replicas=1"
./netbox-enterprise shell -c "kubectl exec -n kotsadm deploy/kotsadm -- /kots set config netbox-enterprise storage_backend=in-cluster --namespace kotsadm --deploy"
