# Kubespray And Ansible

This directory contains local Kubespray inventory, cluster variables, and helper scripts for running Kubespray from this workstation. Upstream Kubespray is cloned into ignored local state under `.kubespray/`; this repository does not vendor or fork Kubespray.

## Workflow

1. Provision node VMs from the golden template with Terraform.
2. Copy `variables/cluster/cluster.env.example` to `variables/cluster/cluster.env`.
3. Copy `variables/cluster/nodes.yaml.example` to `variables/cluster/nodes.yaml`.
4. Update `nodes.yaml` with the Terraform node names and IPs.
5. Run `kubespray/scripts/setup-kubespray.sh`.
6. Run `kubespray/scripts/generate-inventory.sh`.
7. Run `kubespray/scripts/ping-nodes.sh`.
8. Run `kubespray/scripts/run-kubespray.sh`.

## Initial Setup

```bash
cp variables/cluster/cluster.env.example variables/cluster/cluster.env
cp variables/cluster/nodes.yaml.example variables/cluster/nodes.yaml
editor variables/cluster/cluster.env
editor variables/cluster/nodes.yaml
./kubespray/scripts/setup-kubespray.sh
```

`setup-kubespray.sh` creates or reuses `.venv`, clones upstream Kubespray, checks out `KUBESPRAY_VERSION`, installs Python requirements, and installs Ansible collections.

## Inventory

Generate `kubespray/inventory/cluster/hosts.yaml` from `variables/cluster/nodes.yaml`:

```bash
./kubespray/scripts/generate-inventory.sh
```

The generated inventory contains:

- `kube_control_plane`
- `kube_node`
- `etcd`
- `k8s_cluster`
- `calico_rr`

## Connectivity Check

Verify Ansible can reach all nodes:

```bash
./kubespray/scripts/ping-nodes.sh
```

## Cluster Deploy

```bash
./kubespray/scripts/run-kubespray.sh
```

Pass extra Ansible arguments after the script when needed:

```bash
./kubespray/scripts/run-kubespray.sh --limit k8s-cp-01
```

## Local Variables

`variables/cluster/cluster.env` controls workstation-side execution:

- `CLUSTER_NAME`: cluster name used by local config.
- `ANSIBLE_USER`: SSH user on Kubernetes nodes, default `debian`.
- `ANSIBLE_SSH_PRIVATE_KEY_FILE`: optional private key file path for node SSH.
- `KUBESPRAY_REPO_URL`: upstream Kubespray Git repository.
- `KUBESPRAY_VERSION`: branch, tag, or commit to check out.
- `KUBESPRAY_DIR`: local ignored checkout path.
- `KUBESPRAY_INVENTORY`: generated inventory path.
- `ANSIBLE_IGNORE_HOST_KEYS`: ignore rebuilt-node host key changes for lab workflows.
- `KUBESPRAY_EXTRA_ARGS`: optional default extra args for `ansible-playbook`.

## Cluster Variables

Local Kubespray group variables live in `kubespray/inventory/cluster/group_vars/`.

Current defaults:

- Calico CNI.
- containerd runtime.
- Service CIDR `10.233.0.0/18`.
- Pod CIDR `10.233.64.0/18`.
- Host resolv.conf mode.

## Boundaries

- Keep only inventory and local configuration here.
- Do not vendor or edit upstream Kubespray roles/playbooks in this repository.
- Keep generated secrets and kubeconfigs out of Git.
