#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${VENV_DIR:-$ROOT_DIR/.venv}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.8.5}"
TERRAFORM_ARCH="${TERRAFORM_ARCH:-linux_amd64}"

install_terraform() {
  local terraform_bin="$VENV_DIR/bin/terraform"
  local archive_name="terraform_${TERRAFORM_VERSION}_${TERRAFORM_ARCH}.zip"
  local archive_path="/tmp/kilo/${archive_name}"
  local download_url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${archive_name}"

  if [ -x "$terraform_bin" ] && "$terraform_bin" version | grep -q "Terraform v${TERRAFORM_VERSION}"; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to install Terraform." >&2
    exit 1
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip is required to install Terraform." >&2
    exit 1
  fi

  mkdir -p /tmp/kilo "$VENV_DIR/bin"
  curl -fsSL "$download_url" -o "$archive_path"
  unzip -o "$archive_path" terraform -d "$VENV_DIR/bin" >/dev/null
  chmod 0755 "$terraform_bin"
}

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python executable not found: $PYTHON_BIN" >&2
  exit 1
fi

"$PYTHON_BIN" -m venv "$VENV_DIR"

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip setuptools
python -m pip install --upgrade -r "$ROOT_DIR/requirements-dev.txt"
install_terraform
python -m pip check

if command -v pre-commit >/dev/null 2>&1 && [ -f "$ROOT_DIR/.pre-commit-config.yaml" ]; then
  pre-commit install
fi

cat <<EOF
Virtual environment ready: $VENV_DIR
Terraform installed: $VENV_DIR/bin/terraform

Activate it with:
  source "$VENV_DIR/bin/activate"
EOF
