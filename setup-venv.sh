#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${VENV_DIR:-$ROOT_DIR/.venv}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python executable not found: $PYTHON_BIN" >&2
  exit 1
fi

"$PYTHON_BIN" -m venv "$VENV_DIR"

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip setuptools
python -m pip install --upgrade -r "$ROOT_DIR/requirements-dev.txt"
python -m pip check

if command -v pre-commit >/dev/null 2>&1 && [ -f "$ROOT_DIR/.pre-commit-config.yaml" ]; then
  pre-commit install
fi

cat <<EOF
Virtual environment ready: $VENV_DIR

Activate it with:
  source "$VENV_DIR/bin/activate"
EOF
