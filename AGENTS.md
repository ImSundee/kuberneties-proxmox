# Project Guidance

This repository provisions a Kubernetes cluster on Proxmox using Terraform and Kubespray.

## Priorities

- Keep infrastructure changes reproducible and documented.
- Prefer small, explicit Terraform variables over hard-coded environment details.
- Keep Proxmox credentials, SSH keys, Terraform state, kubeconfigs, and generated secrets out of Git.
- Treat the golden image as the foundation for all Kubernetes nodes; document image assumptions before relying on them in Terraform or Kubespray.

## Architecture

- `golden-image/` contains the VM template build workflow and guest preparation scripts.
- `terraform/` provisions Proxmox VMs from the golden image template.
- `kubespray/` contains inventory and group variables consumed by Kubespray.
- `docs/` captures design decisions, runbooks, and project context.

## Conventions

- Use Debian 13 unless a project decision changes the base OS.
- Use cloud-init for hostname, SSH key, and network customization.
- Use static DHCP reservations or explicit VM IPs so Kubespray inventory remains stable.
- Do not edit upstream Kubespray code in this repository; keep only local inventory/configuration here.
