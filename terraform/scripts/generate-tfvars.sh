#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_ENV="${TERRAFORM_ENV:-${ROOT_DIR}/variables/terraform/terraform.env}"
TEMPLATE_ENV="${TEMPLATE_ENV:-${ROOT_DIR}/variables/template/template.env}"
NODES_FILE="${NODES_FILE:-${ROOT_DIR}/variables/cluster/nodes.yaml}"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/terraform/terraform.tfvars}"

if [ ! -f "${TERRAFORM_ENV}" ]; then
  echo "Terraform env file not found: ${TERRAFORM_ENV}"
  echo "Copy variables/terraform/terraform.env.example to variables/terraform/terraform.env first."
  exit 1
fi

if [ ! -f "${TEMPLATE_ENV}" ]; then
  echo "Template env file not found: ${TEMPLATE_ENV}"
  exit 1
fi

if [ ! -f "${NODES_FILE}" ]; then
  echo "Nodes file not found: ${NODES_FILE}"
  exit 1
fi

python3 "${ROOT_DIR}/terraform/scripts/generate-tfvars.py" \
  --terraform-env "${TERRAFORM_ENV}" \
  --template-env "${TEMPLATE_ENV}" \
  --nodes "${NODES_FILE}" \
  --output "${OUTPUT_FILE}"
