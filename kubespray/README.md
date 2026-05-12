# Kubespray Inventory

This directory contains local Kubespray inventory and cluster variables. It is intended to be used with an upstream Kubespray checkout, not as a fork of Kubespray.

## Usage

From an upstream Kubespray checkout, run commands similar to:

```bash
ansible-playbook -i /path/to/this/repo/kubespray/inventory/cluster/hosts.yaml cluster.yml -b -v
```

Update `inventory/cluster/hosts.yaml` after Terraform creates or changes node IPs.

## Boundaries

- Keep only inventory and local configuration here.
- Do not vendor or edit upstream Kubespray roles/playbooks in this repository.
- Keep generated secrets and kubeconfigs out of Git.
