#!/usr/bin/env bash
set -euo pipefail

# Run this from your workstation. It connects to Proxmox over SSH and runs qm remotely.
PROXMOX_HOST="${PROXMOX_HOST:-pve.example.net}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_PORT="${PROXMOX_PORT:-22}"
PROXMOX_SSH_KEY="${PROXMOX_SSH_KEY:-}"

VM_ID="${VM_ID:-9000}"
VM_NAME="${VM_NAME:-debian-13-k8s-template}"
PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
SNIPPET_STORAGE="${SNIPPET_STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
MEMORY_MB="${MEMORY_MB:-2048}"
CORES="${CORES:-2}"
DISK_SIZE="${DISK_SIZE:-20G}"
IMAGE_URL="${IMAGE_URL:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2}"
IMAGE_FILE="${IMAGE_FILE:-/var/lib/vz/template/iso/debian-13-generic-amd64.qcow2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREPARE_SCRIPT="${PREPARE_SCRIPT:-${SCRIPT_DIR}/scripts/prepare-debian-k8s.sh}"
REMOTE_PREPARE_SCRIPT="${REMOTE_PREPARE_SCRIPT:-/var/lib/vz/snippets/prepare-debian-k8s.sh}"

SSH_ARGS=(-p "${PROXMOX_PORT}")
if [ -n "${PROXMOX_SSH_KEY}" ]; then
  SSH_ARGS+=(-i "${PROXMOX_SSH_KEY}")
fi

REMOTE="${PROXMOX_USER}@${PROXMOX_HOST}"

ssh_remote() {
  ssh "${SSH_ARGS[@]}" "${REMOTE}" "$@"
}

scp_remote() {
  scp -P "${PROXMOX_PORT}" ${PROXMOX_SSH_KEY:+-i "${PROXMOX_SSH_KEY}"} "$@"
}

if [ ! -f "${PREPARE_SCRIPT}" ]; then
  echo "Guest preparation script not found: ${PREPARE_SCRIPT}"
  exit 1
fi

ssh_remote "mkdir -p /var/lib/vz/snippets"
scp_remote "${PREPARE_SCRIPT}" "${REMOTE}:${REMOTE_PREPARE_SCRIPT}"
ssh_remote "chmod 0755 '${REMOTE_PREPARE_SCRIPT}'"

ssh_remote \
  "VM_ID='${VM_ID}' VM_NAME='${VM_NAME}' PROXMOX_STORAGE='${PROXMOX_STORAGE}' SNIPPET_STORAGE='${SNIPPET_STORAGE}' BRIDGE='${BRIDGE}' MEMORY_MB='${MEMORY_MB}' CORES='${CORES}' DISK_SIZE='${DISK_SIZE}' IMAGE_URL='${IMAGE_URL}' IMAGE_FILE='${IMAGE_FILE}' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

if qm status "${VM_ID}" >/dev/null 2>&1; then
  echo "VM ${VM_ID} already exists; refusing to overwrite."
  exit 1
fi

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
  --agent enabled=1 \
  --serial0 socket \
  --vga serial0 \
  --scsihw virtio-scsi-pci

qm importdisk "${VM_ID}" "${IMAGE_FILE}" "${PROXMOX_STORAGE}"
qm set "${VM_ID}" --scsi0 "${PROXMOX_STORAGE}:vm-${VM_ID}-disk-0,discard=on,ssd=1"
qm set "${VM_ID}" --ide2 "${SNIPPET_STORAGE}:cloudinit"
qm set "${VM_ID}" --boot order=scsi0
qm set "${VM_ID}" --ciuser debian
qm set "${VM_ID}" --ipconfig0 ip=dhcp
qm disk resize "${VM_ID}" scsi0 "${DISK_SIZE}"

cat <<EOF
Template source VM ${VM_ID} (${VM_NAME}) has been created on Proxmox.

If guest preparation is still needed:
1. Boot a temporary clone or this VM with network access.
2. Run the uploaded script from the guest: ${REMOTE_PREPARE_SCRIPT}
3. Shut down cleanly.
4. Convert the prepared VM to a template from your workstation with:
   ssh ${REMOTE} qm template ${VM_ID}
EOF
REMOTE_SCRIPT
