#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_ENV="${CLUSTER_ENV:-${ROOT_DIR}/variables/cluster/cluster.env}"

if [ -f "${CLUSTER_ENV}" ]; then
  # shellcheck disable=SC1090
  source "${CLUSTER_ENV}"
fi

KUBESPRAY_DIR="${KUBESPRAY_DIR:-${ROOT_DIR}/.kubespray/upstream}"
KUBESPRAY_INVENTORY="${KUBESPRAY_INVENTORY:-${ROOT_DIR}/kubespray/inventory/cluster/hosts.yaml}"
VENV_DIR="${VENV_DIR:-${ROOT_DIR}/.venv}"
ANSIBLE_USER="${ANSIBLE_USER:-debian}"
ANSIBLE_SSH_PRIVATE_KEY_FILE="${ANSIBLE_SSH_PRIVATE_KEY_FILE:-}"
ANSIBLE_IGNORE_HOST_KEYS="${ANSIBLE_IGNORE_HOST_KEYS:-true}"
KUBESPRAY_EXTRA_ARGS="${KUBESPRAY_EXTRA_ARGS:-}"
KUBESPRAY_PLAYBOOK="${KUBESPRAY_PLAYBOOK:-cluster.yml}"

if [ ! -f "${KUBESPRAY_DIR}/${KUBESPRAY_PLAYBOOK}" ]; then
  echo "Kubespray playbook not found: ${KUBESPRAY_DIR}/${KUBESPRAY_PLAYBOOK}"
  echo "Run kubespray/scripts/setup-kubespray.sh first."
  exit 1
fi

if [ ! -f "${KUBESPRAY_INVENTORY}" ]; then
  echo "Inventory not found: ${KUBESPRAY_INVENTORY}"
  echo "Run kubespray/scripts/generate-inventory.sh first."
  exit 1
fi

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"

export ANSIBLE_CONFIG="${ROOT_DIR}/kubespray/ansible.cfg"
if [ "${ANSIBLE_IGNORE_HOST_KEYS}" = "true" ]; then
  export ANSIBLE_HOST_KEY_CHECKING=False
fi

args=(
  -i "${KUBESPRAY_INVENTORY}"
  "${KUBESPRAY_PLAYBOOK}"
  -b
  -u "${ANSIBLE_USER}"
)

if [ -n "${ANSIBLE_SSH_PRIVATE_KEY_FILE}" ]; then
  args+=(--private-key "${ANSIBLE_SSH_PRIVATE_KEY_FILE}")
fi

if [ "$#" -gt 0 ]; then
  args+=("$@")
elif [ -n "${KUBESPRAY_EXTRA_ARGS}" ]; then
  # shellcheck disable=SC2206
  extra_args=(${KUBESPRAY_EXTRA_ARGS})
  args+=("${extra_args[@]}")
fi

cd "${KUBESPRAY_DIR}"
ansible-playbook "${args[@]}"
