# Terraform

This directory provisions Proxmox VMs for Kubernetes nodes by cloning the golden image template.

## Usage

1. Copy `variables/terraform/terraform.env.example` to `variables/terraform/terraform.env`.
2. Update Proxmox API values and VM sizing defaults in `variables/terraform/terraform.env`.
3. Confirm template values in `variables/template/template.env`.
4. Confirm node names and IPs in `variables/cluster/nodes.yaml`.
5. Run `./terraform/scripts/generate-tfvars.sh` from the repository root.
6. Run `./terraform/scripts/install-telmate-provider.sh` from the repository root.
7. Run `TF_CLI_CONFIG_FILE=../.terraformrc terraform init -upgrade` from this directory.
8. Run `terraform plan`.
9. Run `terraform apply` when the plan matches the intended VM layout.

`terraform.tfvars` is intentionally ignored because it can contain local infrastructure details and secrets.

## Variable Sources

`terraform/scripts/generate-tfvars.sh` generates `terraform/terraform.tfvars` from:

- `variables/terraform/terraform.env`: Proxmox API credentials, target Proxmox node, VM sizing defaults, and Kubernetes node SSH public key.
- `variables/template/template.env`: golden template name, storage pool, bridge, gateway, DNS resolver, and DNS domain.
- `variables/cluster/nodes.yaml`: Kubernetes node names and IPs.

Required Terraform-only values:

- `PROXMOX_API_URL`
- `PROXMOX_API_TOKEN_ID`
- `PROXMOX_API_TOKEN_SECRET`
- `TARGET_NODE`
- `KUBERNETES_SSH_PUBLIC_KEY_FILE`

The SSH public key value can be a public key file path or inline public key content.

Set `DISK_DISCARD=true` to enable discard/TRIM support for VM disks. This allows supported thin-provisioned Proxmox storage backends to reclaim unused guest blocks.

## Commands

```bash
cp variables/terraform/terraform.env.example variables/terraform/terraform.env
editor variables/terraform/terraform.env
./terraform/scripts/generate-tfvars.sh
cd terraform
TF_CLI_CONFIG_FILE=../.terraformrc terraform init -upgrade
terraform plan
```

## Telmate Provider

This project uses Telmate provider `3.0.2-rc07` from the GitHub release because the latest release is not available through normal registry version resolution. Run this before `terraform init`:

```bash
./terraform/scripts/install-telmate-provider.sh
```

Then initialize Terraform with the generated CLI config:

```bash
cd terraform
source ../.venv/bin/activate
TF_CLI_CONFIG_FILE=../.terraformrc terraform init -upgrade
```
