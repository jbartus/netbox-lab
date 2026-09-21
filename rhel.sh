#!/bin/bash

set -xeuo pipefail

dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

dnf install -y nftables "kernel-modules-extra-$(uname -r)"

# without br_netfilter loaded the net.bridge.* sysctls don't exist and nbe preflight fails
cat > /etc/modules-load.d/kubernetes.conf <<'MODULES'
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
nf_tables
MODULES

modprobe br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh overlay nf_tables
sysctl --system
