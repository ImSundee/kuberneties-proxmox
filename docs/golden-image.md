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

1. Run `golden-image/proxmox-build-template.sh` from the operator workstation.
2. The script connects to Proxmox over SSH.
3. The remote workflow downloads the Debian 13 generic cloud image on the Proxmox host.
4. The remote workflow creates a Proxmox VM with a stable template VM ID.
5. The remote workflow imports the downloaded disk into Proxmox storage.
6. The remote workflow attaches the imported disk as `scsi0`.
7. The remote workflow adds a cloud-init drive.
8. The remote workflow configures serial console and boot order.
9. Start the VM once if guest validation or preparation is needed.
10. Run the uploaded guest preparation script over SSH from the workstation.
11. Shut down the VM cleanly.
12. Convert the VM to a Proxmox template with a remote SSH command.

## Remote Access Requirements

- Workstation SSH access to the target Proxmox host.
- Permission to run `qm`, create VMs, import disks, and write to `/var/lib/vz/template/iso` and `/var/lib/vz/snippets`.
- Network path from the workstation to temporary guest VMs if guest-side preparation is run after first boot.

## Validation

Before using the template for Kubernetes nodes, validate that a clone can:

- Boot successfully.
- Receive a hostname from cloud-init.
- Receive the expected IP configuration.
- Accept SSH with the expected key.
- Report guest agent information to Proxmox.
- Run `sudo` without interactive configuration issues for the automation user.
