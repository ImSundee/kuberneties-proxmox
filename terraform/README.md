# Terraform

This directory provisions Proxmox VMs for Kubernetes nodes by cloning the golden image template.

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Replace Proxmox, network, template, and node values.
3. Run `terraform init`.
4. Run `terraform plan`.
5. Run `terraform apply` when the plan matches the intended VM layout.

`terraform.tfvars` is intentionally ignored because it can contain local infrastructure details and secrets.
