# Project Context

## Goal

Build a reproducible Kubernetes cluster on Proxmox using:

- A reusable Proxmox golden image.
- Terraform for VM lifecycle management.
- Kubespray for Kubernetes bootstrap and configuration.

## Initial Target Architecture

- Proxmox hosts provide compute, storage, and networking.
- Kubernetes nodes are cloned from a Debian 13 cloud-init golden image template.
- Terraform creates control-plane and worker VMs through the Proxmox API from an operator workstation.
- Kubespray connects over SSH from the operator workstation to install and manage Kubernetes.
- Golden image commands are initiated from the operator workstation and executed on Proxmox remotely over SSH.

## Default Node Roles

| Role | Purpose | Initial Count |
| --- | --- | --- |
| Control plane | Kubernetes API, scheduler, controller manager, etcd membership | 3 |
| Worker | Application workloads | 3 |

The counts are defaults for planning and can be reduced for a lab deployment.

## Key Decisions To Confirm

- Proxmox node names and target storage pools.
- VM bridge and VLAN model.
- Cluster pod/service CIDRs.
- CNI choice.
- Load balancer approach for the Kubernetes API.
- Storage integration for persistent volumes.
- DNS domain and node naming convention.

## Workflow

1. Create the golden image template remotely over SSH.
2. Set Terraform variables for Proxmox, template, network, and node sizing.
3. Run Terraform to clone and configure VMs.
4. Generate or update Kubespray inventory with VM IPs.
5. Run Kubespray against the inventory.
