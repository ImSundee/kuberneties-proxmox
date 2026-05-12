#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROVIDER_VERSION="${PROVIDER_VERSION:-3.0.2-rc07}"
PROVIDER_OS_ARCH="${PROVIDER_OS_ARCH:-linux_amd64}"
PROVIDER_HOST="registry.terraform.io"
PROVIDER_NAMESPACE="Telmate"
PROVIDER_NAME="proxmox"
PROVIDER_SOURCE="${PROVIDER_NAMESPACE}/${PROVIDER_NAME}"
PROVIDER_ZIP="terraform-provider-proxmox_${PROVIDER_VERSION}_${PROVIDER_OS_ARCH}.zip"
PROVIDER_URL="https://github.com/Telmate/terraform-provider-proxmox/releases/download/v${PROVIDER_VERSION}/${PROVIDER_ZIP}"
PLUGIN_DIR="${ROOT_DIR}/.terraform.d/plugins/${PROVIDER_HOST}/${PROVIDER_NAMESPACE}/${PROVIDER_NAME}/${PROVIDER_VERSION}/${PROVIDER_OS_ARCH}"
CLI_CONFIG="${ROOT_DIR}/.terraformrc"
TMP_ZIP="/tmp/kilo/${PROVIDER_ZIP}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to install the Telmate provider."
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required to install the Telmate provider."
  exit 1
fi

mkdir -p "${PLUGIN_DIR}" /tmp/kilo
curl -fsSL "${PROVIDER_URL}" -o "${TMP_ZIP}"
unzip -o "${TMP_ZIP}" -d "${PLUGIN_DIR}" >/dev/null
chmod 0755 "${PLUGIN_DIR}"/terraform-provider-proxmox*

cat >"${CLI_CONFIG}" <<EOF
provider_installation {
  filesystem_mirror {
    path    = "${ROOT_DIR}/.terraform.d/plugins"
    include = ["${PROVIDER_SOURCE}"]
  }

  direct {
    exclude = ["${PROVIDER_SOURCE}"]
  }
}
EOF

echo "Installed ${PROVIDER_SOURCE} ${PROVIDER_VERSION} to ${PLUGIN_DIR}."
echo "Terraform CLI config written to ${CLI_CONFIG}."
echo "Use with: TF_CLI_CONFIG_FILE=${CLI_CONFIG} terraform init -upgrade"
