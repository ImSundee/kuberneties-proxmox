#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  cloud-init \
  conntrack \
  curl \
  gnupg \
  ipset \
  ipvsadm \
  jq \
  nfs-common \
  open-iscsi \
  openssh-server \
  qemu-guest-agent \
  socat

systemctl enable qemu-guest-agent
systemctl enable ssh
systemctl enable iscsid

swapoff -a || true
sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab

cat >/etc/modules-load.d/kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
cloud-init clean --logs
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "Debian Kubernetes golden image preparation complete. Shut down before converting to a template."
