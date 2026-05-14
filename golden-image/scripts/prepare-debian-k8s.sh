#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

wait_for_apt_locks() {
  local timeout_seconds="${APT_LOCK_WAIT_SECONDS:-600}"
  local deadline=$((SECONDS + timeout_seconds))

  while fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if [ "${SECONDS}" -ge "${deadline}" ]; then
      echo "Timed out waiting for apt/dpkg locks."
      exit 1
    fi
    echo "Waiting for apt/dpkg locks to be released..."
    sleep 5
  done
}

wait_for_apt_locks

apt-get update
wait_for_apt_locks
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
for unit in cloud-init-local cloud-init cloud-config cloud-final; do
  if systemctl list-unit-files "${unit}.service" --no-legend | grep -q "^${unit}.service"; then
    systemctl enable "${unit}.service"
  fi
done

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
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dhcp/* /var/lib/systemd/network/* /var/lib/cloud/*
rm -f /etc/cloud/cloud.cfg.d/*disable-network-config*
cloud-init clean --logs --machine-id
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "Debian Kubernetes golden image preparation complete. Shut down before converting to a template."
