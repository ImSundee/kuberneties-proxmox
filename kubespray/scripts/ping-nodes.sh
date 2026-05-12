#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_ENV="${CLUSTER_ENV:-${ROOT_DIR}/variables/cluster/cluster.env}"

if [ -f "${CLUSTER_ENV}" ]; then
  # shellcheck disable=SC1090
  source "${CLUSTER_ENV}"
fi

KUBESPRAY_INVENTORY="${KUBESPRAY_INVENTORY:-${ROOT_DIR}/kubespray/inventory/cluster/hosts.yaml}"
VENV_DIR="${VENV_DIR:-${ROOT_DIR}/.venv}"
ANSIBLE_USER="${ANSIBLE_USER:-debian}"
ANSIBLE_SSH_PRIVATE_KEY_FILE="${ANSIBLE_SSH_PRIVATE_KEY_FILE:-}"

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"

export ANSIBLE_CONFIG="${ROOT_DIR}/kubespray/ansible.cfg"
export ANSIBLE_HOST_KEY_CHECKING=False

args=(all -i "${KUBESPRAY_INVENTORY}" -m ping -u "${ANSIBLE_USER}")
if [ -n "${ANSIBLE_SSH_PRIVATE_KEY_FILE}" ]; then
  args+=(--private-key "${ANSIBLE_SSH_PRIVATE_KEY_FILE}")
fi

ansible "${args[@]}"
