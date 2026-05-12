#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_ENV="${CLUSTER_ENV:-${ROOT_DIR}/variables/cluster/cluster.env}"

if [ -f "${CLUSTER_ENV}" ]; then
  # shellcheck disable=SC1090
  source "${CLUSTER_ENV}"
fi

KUBESPRAY_REPO_URL="${KUBESPRAY_REPO_URL:-https://github.com/kubernetes-sigs/kubespray.git}"
KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-release-2.28}"
KUBESPRAY_DIR="${KUBESPRAY_DIR:-${ROOT_DIR}/.kubespray/upstream}"
VENV_DIR="${VENV_DIR:-${ROOT_DIR}/.venv}"

if [ ! -d "${VENV_DIR}" ]; then
  "${ROOT_DIR}/setup-venv.sh"
fi

if [ ! -d "${KUBESPRAY_DIR}/.git" ]; then
  mkdir -p "$(dirname "${KUBESPRAY_DIR}")"
  git clone "${KUBESPRAY_REPO_URL}" "${KUBESPRAY_DIR}"
fi

git -C "${KUBESPRAY_DIR}" fetch --tags origin
git -C "${KUBESPRAY_DIR}" checkout "${KUBESPRAY_VERSION}"

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"

python -m pip install --upgrade pip setuptools wheel
python -m pip install --upgrade -r "${KUBESPRAY_DIR}/requirements.txt"
ansible-galaxy collection install -r "${KUBESPRAY_DIR}/requirements.yml" --force

echo "Kubespray ready at ${KUBESPRAY_DIR} (${KUBESPRAY_VERSION})."
