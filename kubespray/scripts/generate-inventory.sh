#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_ENV="${CLUSTER_ENV:-${ROOT_DIR}/variables/cluster/cluster.env}"

if [ -f "${CLUSTER_ENV}" ]; then
  # shellcheck disable=SC1090
  source "${CLUSTER_ENV}"
fi

NODES_FILE="${NODES_FILE:-${ROOT_DIR}/variables/cluster/nodes.yaml}"
KUBESPRAY_INVENTORY="${KUBESPRAY_INVENTORY:-${ROOT_DIR}/kubespray/inventory/cluster/hosts.yaml}"

if [ ! -f "${NODES_FILE}" ]; then
  echo "Nodes file not found: ${NODES_FILE}"
  echo "Copy variables/cluster/nodes.yaml.example to variables/cluster/nodes.yaml first."
  exit 1
fi

python3 "${ROOT_DIR}/kubespray/scripts/generate-inventory.py" --nodes "${NODES_FILE}" --output "${KUBESPRAY_INVENTORY}"
