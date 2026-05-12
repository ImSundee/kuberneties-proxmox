# Golden Image Runbook

## Purpose

The golden image is a Proxmox VM template used as the base for all Kubernetes nodes. It should contain only generic OS preparation and Kubernetes prerequisites. Cluster-specific configuration belongs in Terraform or Kubespray.

All steps are initiated from an operator workstation. Proxmox shell commands are executed remotely over SSH by repository scripts.

## Baseline

- OS: Debian 13 cloud image.
- Access: cloud-init SSH key injection.
- User: `debian` by default, overridden through cloud-init if needed.
- Disk: virtio SCSI.
- Network: virtio NIC on the target Proxmox bridge.

## Image Requirements

- `cloud-init` installed and enabled.
- QEMU guest agent installed and enabled.
- SSH server enabled.
- Container runtime prerequisites available to Kubespray.
- Swap disabled.
- Kernel modules and sysctl values suitable for Kubernetes networking.
- Package cache cleaned before converting to a template.

## High-Level Build Steps

1. Copy `variables/template/template.env.example` to `variables/template/template.env`.
2. Update `variables/template/template.env` for the target Proxmox host and template settings.
3. Run `golden-image/proxmox-build-template.sh` from the operator workstation.
4. The script connects to Proxmox over SSH.
5. The remote workflow downloads the Debian 13 generic cloud image on the Proxmox host.
6. The remote workflow creates a Proxmox VM with a stable template VM ID.
7. The remote workflow imports the downloaded disk into Proxmox storage.
8. The remote workflow attaches the imported disk as `scsi0`.
9. The remote workflow adds a cloud-init drive.
10. The remote workflow injects `TEMPLATE_SSH_PUBLIC_KEY_FILE` into the source VM through Proxmox cloud-init.
11. The remote workflow configures serial console and boot order.
12. The script configures the source VM with `TEMPLATE_IP` when set, otherwise DHCP.
13. The script starts the source VM when `AUTO_PREPARE_TEMPLATE=true`.
14. The script uses `TEMPLATE_IP` for SSH when set, otherwise discovers the source VM IPv4 address from Proxmox guest-agent data unless `TEMPLATE_SSH_HOST` is set.
15. The script waits for SSH on the discovered or configured address.
16. The script copies and runs the guest preparation script.
17. The script verifies guest preparation checks.
18. The script shuts down the VM cleanly.
19. The script converts the VM to a Proxmox template when `AUTO_CONVERT_TEMPLATE=true`.

## Remote Access Requirements

- Workstation SSH access to the target Proxmox host.
- Permission to run `qm`, create VMs, import disks, and write to `/var/lib/vz/template/iso` and `/var/lib/vz/snippets`.
- Network path from the workstation to the template source VM address reported by the Proxmox guest agent.
- Working QEMU guest agent in the source VM before automatic IP discovery can succeed.

## Automatic Preparation Checks

The template workflow fails if any required check fails:

- `qemu-guest-agent` is enabled.
- `ssh` is enabled.
- Swap is disabled.
- `overlay` is loaded.
- `br_netfilter` is loaded.
- `net.bridge.bridge-nf-call-iptables` is `1`.
- `net.bridge.bridge-nf-call-ip6tables` is `1`.
- `net.ipv4.ip_forward` is `1`.
- `conntrack` is installed.
- `ipvsadm` is installed.
- `qemu-ga` is installed.

## Validation

Before using the template for Kubernetes nodes, validate that a clone can:

- Boot successfully.
- Receive a hostname from cloud-init.
- Receive the expected IP configuration.
- Accept SSH with the expected key.
- Report guest agent information to Proxmox.
- Run `sudo` without interactive configuration issues for the automation user.
