#!/usr/bin/env python3
import argparse
import json
import os
import re
from pathlib import Path

import yaml


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    pattern = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = pattern.match(line)
        if not match:
            continue
        key, value = match.groups()
        value = value.strip()
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]
        value = value.replace("${HOME}", str(Path.home())).replace("${PWD}", str(Path.cwd()))
        values[key] = value
    return values


def bool_value(value: str, default: bool = True) -> bool:
    if value == "":
        return default
    return value.lower() in {"1", "true", "yes", "y"}


def public_key(value: str) -> str:
    if value.startswith(("ssh-rsa ", "ssh-ed25519 ", "ecdsa-sha2-")):
        return value
    path = Path(value).expanduser()
    if not path.exists():
        raise SystemExit(f"SSH public key not found: {path}")
    return path.read_text(encoding="utf-8").strip()


def node_map(nodes: list[dict], vmid_start: int, cores: int, memory: int, disk_size: str) -> dict:
    generated = {}
    for index, node in enumerate(nodes):
        generated[node["name"]] = {
            "vmid": vmid_start + index,
            "ip": str(node["ip"]),
            "cidr": int(node.get("cidr", 24)),
            "cores": cores,
            "memory": memory,
            "disk_size": disk_size,
        }
    return generated


def hcl_value(value) -> str:
    return json.dumps(value)


def hcl_node_map(name: str, nodes: dict) -> str:
    lines = [f"{name} = {{"]
    for node_name, node in nodes.items():
        lines.append(f"  {node_name} = {{")
        for key, value in node.items():
            lines.append(f"    {key} = {hcl_value(value)}")
        lines.append("  }")
    lines.append("}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate terraform.tfvars from project variable files")
    parser.add_argument("--terraform-env", required=True)
    parser.add_argument("--template-env", required=True)
    parser.add_argument("--nodes", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    terraform_env = parse_env(Path(args.terraform_env))
    template_env = parse_env(Path(args.template_env))

    with Path(args.nodes).open("r", encoding="utf-8") as handle:
        nodes = yaml.safe_load(handle) or {}

    required = ["PROXMOX_API_URL", "PROXMOX_API_TOKEN_ID", "PROXMOX_API_TOKEN_SECRET", "TARGET_NODE"]
    missing = [key for key in required if not terraform_env.get(key)]
    if missing:
        raise SystemExit(f"Missing required Terraform env values: {', '.join(missing)}")

    key_source = terraform_env.get("KUBERNETES_SSH_PUBLIC_KEY_FILE") or template_env.get("TEMPLATE_SSH_PUBLIC_KEY_FILE")
    if not key_source:
        raise SystemExit("Missing KUBERNETES_SSH_PUBLIC_KEY_FILE or TEMPLATE_SSH_PUBLIC_KEY_FILE")

    control_plane_nodes = node_map(
        nodes.get("control_plane", []),
        int(terraform_env.get("CONTROL_PLANE_VMID_START", "2101")),
        int(terraform_env.get("CONTROL_PLANE_CORES", "2")),
        int(terraform_env.get("CONTROL_PLANE_MEMORY", "4096")),
        terraform_env.get("CONTROL_PLANE_DISK_SIZE", "40G"),
    )
    worker_nodes = node_map(
        nodes.get("workers", []),
        int(terraform_env.get("WORKER_VMID_START", "2201")),
        int(terraform_env.get("WORKER_CORES", "4")),
        int(terraform_env.get("WORKER_MEMORY", "8192")),
        terraform_env.get("WORKER_DISK_SIZE", "80G"),
    )

    values = {
        "proxmox_api_url": terraform_env["PROXMOX_API_URL"],
        "proxmox_api_token_id": terraform_env["PROXMOX_API_TOKEN_ID"],
        "proxmox_api_token_secret": terraform_env["PROXMOX_API_TOKEN_SECRET"],
        "proxmox_tls_insecure": bool_value(terraform_env.get("PROXMOX_TLS_INSECURE", "true")),
        "target_node": terraform_env["TARGET_NODE"],
        "template_name": template_env.get("VM_NAME", "debian-13-k8s-template"),
        "storage_pool": template_env.get("PROXMOX_STORAGE", "local-lvm"),
        "full_clone": bool_value(terraform_env.get("FULL_CLONE", "false")),
        "disk_discard": bool_value(terraform_env.get("DISK_DISCARD", "true")),
        "network_bridge": template_env.get("BRIDGE", "vmbr0"),
        "ssh_public_key": public_key(key_source),
        "cloud_init_user": terraform_env.get("CLOUD_INIT_USER", template_env.get("TEMPLATE_SSH_USER", "debian")),
        "nameserver": terraform_env.get("NAMESERVER", template_env.get("TEMPLATE_NAMESERVER", "")),
        "gateway": terraform_env.get("GATEWAY", template_env.get("TEMPLATE_GATEWAY", "")),
        "dns_domain": terraform_env.get("DNS_DOMAIN", template_env.get("TEMPLATE_SEARCH_DOMAIN", "cluster.local")),
    }

    missing_values = [key for key in ["nameserver", "gateway"] if not values[key]]
    if missing_values:
        raise SystemExit(f"Missing required network values: {', '.join(missing_values)}")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Generated by terraform/scripts/generate-tfvars.py. Do not commit this file."]
    for key, value in values.items():
        lines.append(f"{key} = {hcl_value(value)}")
    lines.append("")
    lines.append(hcl_node_map("control_plane_nodes", control_plane_nodes))
    lines.append("")
    lines.append(hcl_node_map("worker_nodes", worker_nodes))
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Generated {output}")


if __name__ == "__main__":
    main()
