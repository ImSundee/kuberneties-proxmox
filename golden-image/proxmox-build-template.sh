#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VARIABLES_FILE="${VARIABLES_FILE:-${REPO_ROOT}/variables/template/template.env}"

if [ -f "${VARIABLES_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${VARIABLES_FILE}"
fi

# Run this from your workstation. It connects to Proxmox over SSH and runs qm remotely.
PROXMOX_HOST="${PROXMOX_HOST:-pve.example.net}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_PORT="${PROXMOX_PORT:-22}"
PROXMOX_SSH_PRIVATE_KEY_FILE="${PROXMOX_SSH_PRIVATE_KEY_FILE:-${PROXMOX_SSH_KEY:-}}"

VM_ID="${VM_ID:-9000}"
VM_NAME="${VM_NAME:-debian-13-k8s-template}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
SNIPPET_STORAGE="${SNIPPET_STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
MEMORY_MB="${MEMORY_MB:-2048}"
CORES="${CORES:-2}"
DISK_SIZE="${DISK_SIZE:-20G}"
TEMPLATE_IP="${TEMPLATE_IP:-}"
TEMPLATE_CIDR="${TEMPLATE_CIDR:-24}"
TEMPLATE_GATEWAY="${TEMPLATE_GATEWAY:-}"
TEMPLATE_NAMESERVER="${TEMPLATE_NAMESERVER:-}"
TEMPLATE_SEARCH_DOMAIN="${TEMPLATE_SEARCH_DOMAIN:-}"
IMAGE_URL="${IMAGE_URL:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2}"
IMAGE_FILE="${IMAGE_FILE:-/var/lib/vz/template/iso/debian-13-generic-amd64.qcow2}"

PREPARE_SCRIPT="${PREPARE_SCRIPT:-${SCRIPT_DIR}/scripts/prepare-debian-k8s.sh}"
REMOTE_PREPARE_SCRIPT="${REMOTE_PREPARE_SCRIPT:-/var/lib/vz/snippets/prepare-debian-k8s.sh}"
AUTO_PREPARE_TEMPLATE="${AUTO_PREPARE_TEMPLATE:-true}"
AUTO_CONVERT_TEMPLATE="${AUTO_CONVERT_TEMPLATE:-true}"
TEMPLATE_SSH_USER="${TEMPLATE_SSH_USER:-debian}"
TEMPLATE_SSH_PUBLIC_KEY_FILE="${TEMPLATE_SSH_PUBLIC_KEY_FILE:-${HOME}/.ssh/id_ed25519.pub}"
TEMPLATE_SSH_HOST="${TEMPLATE_SSH_HOST:-}"
TEMPLATE_SSH_PORT="${TEMPLATE_SSH_PORT:-22}"
TEMPLATE_SSH_PRIVATE_KEY_FILE="${TEMPLATE_SSH_PRIVATE_KEY_FILE:-${TEMPLATE_SSH_KEY:-}}"
TEMPLATE_SSH_WAIT_SECONDS="${TEMPLATE_SSH_WAIT_SECONDS:-300}"
TEMPLATE_IP_WAIT_SECONDS="${TEMPLATE_IP_WAIT_SECONDS:-300}"
TEMPLATE_SSH_PUBLIC_KEY_SOURCE=""
REMOTE_TEMPLATE_SSH_PUBLIC_KEY_FILE="/var/lib/vz/snippets/${VM_NAME}-ssh-public-key.pub"
IPCONFIG0="ip=dhcp"

if [ -n "${TEMPLATE_IP}" ]; then
  if [ -z "${TEMPLATE_GATEWAY}" ]; then
    echo "TEMPLATE_IP is set, but TEMPLATE_GATEWAY is empty."
    exit 1
  fi
  IPCONFIG0="ip=${TEMPLATE_IP}/${TEMPLATE_CIDR},gw=${TEMPLATE_GATEWAY}"
  TEMPLATE_SSH_HOST="${TEMPLATE_SSH_HOST:-${TEMPLATE_IP}}"
fi

SSH_ARGS=(-p "${PROXMOX_PORT}")
if [ -n "${PROXMOX_SSH_PRIVATE_KEY_FILE}" ]; then
  SSH_ARGS+=(-i "${PROXMOX_SSH_PRIVATE_KEY_FILE}")
fi

REMOTE="${PROXMOX_USER}@${PROXMOX_HOST}"

ssh_remote() {
  ssh "${SSH_ARGS[@]}" "${REMOTE}" "$@"
}

scp_remote() {
  scp -P "${PROXMOX_PORT}" ${PROXMOX_SSH_PRIVATE_KEY_FILE:+-i "${PROXMOX_SSH_PRIVATE_KEY_FILE}"} "$@"
}

template_ssh_args() {
  local args=(-p "${TEMPLATE_SSH_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  if [ -n "${TEMPLATE_SSH_PRIVATE_KEY_FILE}" ]; then
    args+=(-i "${TEMPLATE_SSH_PRIVATE_KEY_FILE}")
  elif [ -n "${PROXMOX_SSH_PRIVATE_KEY_FILE}" ]; then
    args+=(-i "${PROXMOX_SSH_PRIVATE_KEY_FILE}")
  fi
  printf '%s\n' "${args[@]}"
}

template_scp_args() {
  local args=(-P "${TEMPLATE_SSH_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  if [ -n "${TEMPLATE_SSH_PRIVATE_KEY_FILE}" ]; then
    args+=(-i "${TEMPLATE_SSH_PRIVATE_KEY_FILE}")
  elif [ -n "${PROXMOX_SSH_PRIVATE_KEY_FILE}" ]; then
    args+=(-i "${PROXMOX_SSH_PRIVATE_KEY_FILE}")
  fi
  printf '%s\n' "${args[@]}"
}

confirm_remove_existing_vm() {
  if ! ssh_remote "qm status '${VM_ID}' >/dev/null 2>&1"; then
    return 0
  fi

  local answer=""
  printf 'VM %s already exists on %s. Remove it and continue? [y/N] ' "${VM_ID}" "${PROXMOX_HOST}"
  read -r answer

  case "${answer}" in
    y|Y|yes|YES)
      ssh_remote "if qm status '${VM_ID}' | grep -q running; then qm stop '${VM_ID}' --skiplock 1; fi; qm destroy '${VM_ID}' --purge 1 --destroy-unreferenced-disks 1"
      echo "Removed existing VM ${VM_ID}."
      ;;
    *)
      echo "Existing VM ${VM_ID} was not removed. Exiting."
      exit 0
      ;;
  esac
}

wait_for_template_ssh() {
  local deadline=$((SECONDS + TEMPLATE_SSH_WAIT_SECONDS))
  local ssh_args=()
  mapfile -t ssh_args < <(template_ssh_args)

  until ssh "${ssh_args[@]}" "${TEMPLATE_SSH_USER}@${TEMPLATE_SSH_HOST}" "true" >/dev/null 2>&1; do
    if [ "${SECONDS}" -ge "${deadline}" ]; then
      echo "Timed out waiting for SSH on ${TEMPLATE_SSH_USER}@${TEMPLATE_SSH_HOST}:${TEMPLATE_SSH_PORT}."
      exit 1
    fi
    sleep 5
  done
}

discover_template_ip() {
  local deadline=$((SECONDS + TEMPLATE_IP_WAIT_SECONDS))
  local discovered_ip=""

  while [ -z "${discovered_ip}" ]; do
    discovered_ip="$(ssh_remote "qm guest cmd '${VM_ID}' network-get-interfaces 2>/dev/null | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

interfaces = data if isinstance(data, list) else data.get("result", [])
for interface in interfaces:
    name = interface.get("name", "")
    if name == "lo":
        continue
    for address in interface.get("ip-addresses", []):
        if address.get("ip-address-type") == "ipv4":
            ip = address.get("ip-address", "")
            if ip and not ip.startswith("127.") and not ip.startswith("169.254."):
                print(ip)
                sys.exit(0)
'" || true)"

    if [ -n "${discovered_ip}" ]; then
      TEMPLATE_SSH_HOST="${discovered_ip}"
      echo "Discovered template VM IP from Proxmox guest agent: ${TEMPLATE_SSH_HOST}"
      return 0
    fi

    if [ "${SECONDS}" -ge "${deadline}" ]; then
      echo "Timed out waiting for Proxmox guest agent to report an IPv4 address for VM ${VM_ID}."
      exit 1
    fi

    sleep 5
  done
}

run_guest_prepare_and_checks() {
  local ssh_args=()
  local scp_args=()
  mapfile -t ssh_args < <(template_ssh_args)
  mapfile -t scp_args < <(template_scp_args)

  scp "${scp_args[@]}" "${PREPARE_SCRIPT}" "${TEMPLATE_SSH_USER}@${TEMPLATE_SSH_HOST}:/tmp/prepare-debian-k8s.sh"
  ssh "${ssh_args[@]}" "${TEMPLATE_SSH_USER}@${TEMPLATE_SSH_HOST}" "sudo bash /tmp/prepare-debian-k8s.sh"
  ssh "${ssh_args[@]}" "${TEMPLATE_SSH_USER}@${TEMPLATE_SSH_HOST}" "sudo bash -s" <<'GUEST_CHECKS'
set -euo pipefail

systemctl is-enabled qemu-guest-agent >/dev/null
systemctl is-enabled ssh >/dev/null
if [ -n "$(/sbin/swapon --show --noheadings)" ]; then
  echo "Swap is still enabled."
  exit 1
fi

lsmod | grep -q '^overlay '
lsmod | grep -q '^br_netfilter '

[ "$(/sbin/sysctl -n net.bridge.bridge-nf-call-iptables)" = "1" ]
[ "$(/sbin/sysctl -n net.bridge.bridge-nf-call-ip6tables)" = "1" ]
[ "$(/sbin/sysctl -n net.ipv4.ip_forward)" = "1" ]

command -v conntrack >/dev/null
command -v ipvsadm >/dev/null
command -v qemu-ga >/dev/null

echo "Guest preparation checks passed."
GUEST_CHECKS
}

if [ ! -f "${PREPARE_SCRIPT}" ]; then
  echo "Guest preparation script not found: ${PREPARE_SCRIPT}"
  exit 1
fi

if [ -n "${TEMPLATE_SSH_PUBLIC_KEY_FILE}" ]; then
  if [ -f "${TEMPLATE_SSH_PUBLIC_KEY_FILE}" ]; then
    TEMPLATE_SSH_PUBLIC_KEY_SOURCE="${TEMPLATE_SSH_PUBLIC_KEY_FILE}"
  elif [[ "${TEMPLATE_SSH_PUBLIC_KEY_FILE}" =~ ^ssh-(rsa|ed25519)|^ecdsa-sha2- ]]; then
    TEMPLATE_SSH_PUBLIC_KEY_SOURCE="$(mktemp)"
    printf '%s\n' "${TEMPLATE_SSH_PUBLIC_KEY_FILE}" >"${TEMPLATE_SSH_PUBLIC_KEY_SOURCE}"
  else
    echo "TEMPLATE_SSH_PUBLIC_KEY_FILE must be a public key file path or inline public key content."
    exit 1
  fi
fi

ssh_remote "mkdir -p /var/lib/vz/snippets"
scp_remote "${PREPARE_SCRIPT}" "${REMOTE}:${REMOTE_PREPARE_SCRIPT}"
ssh_remote "chmod 0755 '${REMOTE_PREPARE_SCRIPT}'"
if [ -n "${TEMPLATE_SSH_PUBLIC_KEY_SOURCE}" ]; then
  scp_remote "${TEMPLATE_SSH_PUBLIC_KEY_SOURCE}" "${REMOTE}:${REMOTE_TEMPLATE_SSH_PUBLIC_KEY_FILE}"
fi

confirm_remove_existing_vm

ssh_remote \
  "VM_ID='${VM_ID}' VM_NAME='${VM_NAME}' PROXMOX_STORAGE='${PROXMOX_STORAGE}' SNIPPET_STORAGE='${SNIPPET_STORAGE}' BRIDGE='${BRIDGE}' MEMORY_MB='${MEMORY_MB}' CORES='${CORES}' DISK_SIZE='${DISK_SIZE}' IPCONFIG0='${IPCONFIG0}' TEMPLATE_NAMESERVER='${TEMPLATE_NAMESERVER}' TEMPLATE_SEARCH_DOMAIN='${TEMPLATE_SEARCH_DOMAIN}' IMAGE_URL='${IMAGE_URL}' IMAGE_FILE='${IMAGE_FILE}' REMOTE_TEMPLATE_SSH_PUBLIC_KEY_FILE='${REMOTE_TEMPLATE_SSH_PUBLIC_KEY_FILE}' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

mkdir -p "$(dirname "${IMAGE_FILE}")"

if [ ! -f "${IMAGE_FILE}" ]; then
  wget -O "${IMAGE_FILE}" "${IMAGE_URL}"
fi

qm create "${VM_ID}" \
  --name "${VM_NAME}" \
  --memory "${MEMORY_MB}" \
  --cores "${CORES}" \
  --net0 "virtio,bridge=${BRIDGE}" \
  --ostype l26 \
  --bios ovmf \
  --machine q35 \
  --agent enabled=1 \
  --scsihw virtio-scsi-pci

qm importdisk "${VM_ID}" "${IMAGE_FILE}" "${PROXMOX_STORAGE}"
qm set "${VM_ID}" --efidisk0 "${PROXMOX_STORAGE}:0,efitype=4m,pre-enrolled-keys=0"
qm set "${VM_ID}" --scsi0 "${PROXMOX_STORAGE}:vm-${VM_ID}-disk-0,discard=on,ssd=1"
qm set "${VM_ID}" --ide2 "${SNIPPET_STORAGE}:cloudinit"
qm set "${VM_ID}" --boot order=scsi0
qm set "${VM_ID}" --ciuser debian
if [ -f "${REMOTE_TEMPLATE_SSH_PUBLIC_KEY_FILE}" ]; then
  qm set "${VM_ID}" --sshkeys "${REMOTE_TEMPLATE_SSH_PUBLIC_KEY_FILE}"
fi
qm set "${VM_ID}" --ipconfig0 "${IPCONFIG0}"
if [ -n "${TEMPLATE_NAMESERVER}" ]; then
  qm set "${VM_ID}" --nameserver "${TEMPLATE_NAMESERVER}"
fi
if [ -n "${TEMPLATE_SEARCH_DOMAIN}" ]; then
  qm set "${VM_ID}" --searchdomain "${TEMPLATE_SEARCH_DOMAIN}"
fi
qm disk resize "${VM_ID}" scsi0 "${DISK_SIZE}"

echo "Template source VM ${VM_ID} (${VM_NAME}) has been created on Proxmox."
REMOTE_SCRIPT

if [ "${AUTO_PREPARE_TEMPLATE}" = "true" ]; then
  ssh_remote "qm start '${VM_ID}'"
  if [ -z "${TEMPLATE_SSH_HOST}" ]; then
    discover_template_ip
  fi
  wait_for_template_ssh
  run_guest_prepare_and_checks
  template_shutdown_ssh_args=()
  mapfile -t template_shutdown_ssh_args < <(template_ssh_args)
  ssh "${template_shutdown_ssh_args[@]}" "${TEMPLATE_SSH_USER}@${TEMPLATE_SSH_HOST}" "sudo shutdown -h now" || true
  ssh_remote "timeout 300 bash -c 'until qm status ${VM_ID} | grep -q stopped; do sleep 5; done'"
  ssh_remote "qm set '${VM_ID}' --delete ipconfig0 --delete nameserver --delete searchdomain"

  if [ "${AUTO_CONVERT_TEMPLATE}" = "true" ]; then
    ssh_remote "qm template '${VM_ID}'"
    echo "Template VM ${VM_ID} (${VM_NAME}) prepared, verified, shut down, and converted to a template."
  else
    echo "Template source VM ${VM_ID} (${VM_NAME}) prepared, verified, and shut down. AUTO_CONVERT_TEMPLATE=false, so it was not converted."
  fi
else
  echo "Template source VM ${VM_ID} (${VM_NAME}) created. AUTO_PREPARE_TEMPLATE=false, so guest preparation was skipped."
fi
