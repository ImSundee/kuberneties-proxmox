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

1. Copy `variables/template/template.env.example` to `variables/template/template.env`.
2. Update `variables/template/template.env` for your Proxmox host, storage, bridge, and template VM ID.
3. Run `./golden-image/proxmox-build-template.sh` from this repository on your workstation.
4. The script creates the VM, boots it, waits for SSH, runs guest prep, verifies the checks, shuts it down, and converts it to a template.
5. Set Terraform `template_name` to the final template name.

If `VM_ID` already exists on Proxmox, the script asks whether to stop and destroy that VM before continuing. Answering anything other than `y` or `yes` exits without changes to the existing VM.

The script is intentionally a starting template. Review storage, bridge, VM ID, SSH target, and image URL before running it against a real Proxmox host.

## Remote Variables

The script loads `variables/template/template.env` by default. Override the file path with `VARIABLES_FILE=/path/to/template.env` when needed. Shell environment variables still take precedence for values not set by the file.

- `PROXMOX_HOST`: Proxmox host reachable over SSH.
- `PROXMOX_USER`: SSH user, default `root`.
- `PROXMOX_PORT`: SSH port, default `22`.
- `PROXMOX_SSH_PRIVATE_KEY_FILE`: optional private key file path for SSH to Proxmox.
- `VM_ID`: template source VM ID, default `9000`.
- `VM_NAME`: template source VM name, default `debian-13-k8s-template`.
- `PROXMOX_STORAGE`: target disk storage, default `local-lvm`.
- `SNIPPET_STORAGE`: cloud-init snippet storage, default `local`.
- `BRIDGE`: VM bridge, default `vmbr0`.
- `TEMPLATE_IP`: optional static IPv4 address for the template source VM. Leave empty for DHCP.
- `TEMPLATE_CIDR`: CIDR prefix for `TEMPLATE_IP`, default `24`.
- `TEMPLATE_GATEWAY`: gateway required when `TEMPLATE_IP` is set.
- `TEMPLATE_NAMESERVER`: optional DNS resolver for cloud-init.
- `TEMPLATE_SEARCH_DOMAIN`: optional DNS search domain for cloud-init.
- `AUTO_PREPARE_TEMPLATE`: boot the VM and run guest preparation, default `true`.
- `AUTO_CONVERT_TEMPLATE`: convert the VM to a template after checks pass, default `true`.
- `TEMPLATE_SSH_PUBLIC_KEY_FILE`: public key file path or inline public key content injected into the template source VM by Proxmox cloud-init for prep access.
- `TEMPLATE_SSH_HOST`: optional IP or DNS override for guest preparation. Leave empty to discover the IP from Proxmox guest-agent data.
- `TEMPLATE_SSH_USER`: guest SSH user, default `debian`.
- `TEMPLATE_SSH_PRIVATE_KEY_FILE`: optional private key file path for the guest VM. Falls back to `PROXMOX_SSH_PRIVATE_KEY_FILE` when empty.
- `TEMPLATE_IP_WAIT_SECONDS`: time to wait for Proxmox guest-agent IP discovery, default `300`.

## Automatic Checks

The automatic preparation step verifies:

- QEMU guest agent and SSH are enabled.
- Swap is disabled.
- `overlay` and `br_netfilter` modules are loaded.
- Required Kubernetes sysctls are set.
- `conntrack`, `ipvsadm`, and `qemu-ga` are installed.

Example:

```bash
cp variables/template/template.env.example variables/template/template.env
editor variables/template/template.env
./golden-image/proxmox-build-template.sh
```
