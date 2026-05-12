# Golden Image

This directory captures the repeatable process for creating the Proxmox VM template used by Terraform.

## Files

- `proxmox-build-template.sh`: remote SSH workflow for creating a Debian 13 cloud-init VM template on a Proxmox host.
- `scripts/prepare-debian-k8s.sh`: guest-side preparation script for Kubernetes prerequisites.

## Expected Template

- Template name: `debian-13-k8s-template` by default.
- OS: Debian 13 generic cloud image.
- Cloud-init enabled.
- QEMU guest agent enabled.
- SSH key access managed by Terraform/cloud-init.

## Process

1. Set `PROXMOX_HOST` and any required override variables in your shell.
2. Run `./golden-image/proxmox-build-template.sh` from this repository on your workstation.
3. If guest preparation is needed, boot a temporary VM and run the uploaded preparation script through SSH.
4. Convert the VM to a template with a remote SSH command.
5. Set Terraform `template_name` to the final template name.

The script is intentionally a starting template. Review storage, bridge, VM ID, SSH target, and image URL before running it against a real Proxmox host.

## Remote Variables

- `PROXMOX_HOST`: Proxmox host reachable over SSH.
- `PROXMOX_USER`: SSH user, default `root`.
- `PROXMOX_PORT`: SSH port, default `22`.
- `PROXMOX_SSH_KEY`: optional private key path for SSH.
- `VM_ID`: template source VM ID, default `9000`.
- `VM_NAME`: template source VM name, default `debian-13-k8s-template`.
- `PROXMOX_STORAGE`: target disk storage, default `local-lvm`.
- `SNIPPET_STORAGE`: cloud-init snippet storage, default `local`.
- `BRIDGE`: VM bridge, default `vmbr0`.

Example:

```bash
PROXMOX_HOST=pve01.example.net PROXMOX_SSH_KEY=~/.ssh/proxmox ./golden-image/proxmox-build-template.sh
```
