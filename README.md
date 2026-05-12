# Kubernetes on Proxmox

Infrastructure-as-code workspace for building a Kubernetes cluster on Proxmox.

The intended flow is:

1. Build and maintain a reusable Proxmox golden image remotely over SSH.
2. Provision Kubernetes node VMs from that template with Terraform from this workstation.
3. Configure Kubernetes with Kubespray from this workstation.

## Next Steps After Template Creation

1. Use Terraform to provision the Kubernetes node VMs from `debian-13-k8s-template`.
2. Generate `terraform/terraform.tfvars` with `./terraform/scripts/generate-tfvars.sh`.
3. Run `terraform init`, `terraform plan`, and `terraform apply` from `terraform/`.
4. Update `variables/cluster/nodes.yaml` with the node names and IPs if they changed.
5. Generate the Kubespray inventory with `./kubespray/scripts/generate-inventory.sh`.
6. Verify SSH connectivity with `./kubespray/scripts/ping-nodes.sh`.
7. Deploy Kubernetes with `./kubespray/scripts/run-kubespray.sh`.

## Repository Layout

```text
.
├── docs/                  # Project context and runbooks
├── golden-image/          # Golden image preparation notes and scripts
├── kubespray/             # Kubespray inventory and cluster variables
├── terraform/             # Proxmox VM provisioning
└── variables/             # Step-specific local variable examples
```

## Current Phase

The first milestone is the golden image. Terraform and Kubespray are scaffolded so decisions made during image creation can be captured in the correct places as the project evolves.

## Tooling

- Proxmox VE for virtualization.
- Terraform with the Telmate Proxmox provider for VM provisioning.
- Kubespray for Kubernetes installation and cluster lifecycle.
- Debian 13 cloud image as the default golden image base.

## Remote Execution

All project workflows are intended to run from this repository on an operator workstation. Proxmox host commands are executed remotely over SSH or through the Proxmox API; nothing in this repository should require opening a shell directly on a Proxmox host.

## Sensitive Values

Do not commit secrets, API tokens, SSH private keys, kubeconfigs, Terraform state, or generated inventories containing credentials. Use local `*.tfvars`, environment variables, or secret management outside Git.
=======
# kuberneties-proxmox
Install kuberneties cluster in proxmox...

## Development Environment

Create or refresh the project virtual environment with:

```bash
./setup-venv.sh
```

This creates `.venv`, upgrades core packaging tools, and installs the latest versions of the tools listed in `requirements-dev.txt`.

Activate the environment with:

```bash
source .venv/bin/activate
```
