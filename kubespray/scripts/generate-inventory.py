#!/usr/bin/env python3
import argparse
from pathlib import Path

import yaml


def host_entry(node):
    return {
        "ansible_host": node["ip"],
        "ip": node["ip"],
        "access_ip": node["ip"],
    }


def main():
    parser = argparse.ArgumentParser(description="Generate Kubespray inventory from nodes.yaml")
    parser.add_argument("--nodes", required=True, help="Path to variables/cluster/nodes.yaml")
    parser.add_argument("--output", required=True, help="Path to Kubespray hosts.yaml")
    args = parser.parse_args()

    nodes_path = Path(args.nodes)
    output_path = Path(args.output)

    with nodes_path.open("r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle) or {}

    control_plane = config.get("control_plane", [])
    workers = config.get("workers", [])
    all_nodes = control_plane + workers

    inventory = {
        "all": {
            "hosts": {node["name"]: host_entry(node) for node in all_nodes},
            "children": {
                "kube_control_plane": {
                    "hosts": {node["name"]: None for node in control_plane},
                },
                "kube_node": {
                    "hosts": {node["name"]: None for node in workers},
                },
                "etcd": {
                    "hosts": {node["name"]: None for node in control_plane},
                },
                "k8s_cluster": {
                    "children": {
                        "kube_control_plane": None,
                        "kube_node": None,
                    },
                },
                "calico_rr": {"hosts": {}},
            },
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(inventory, handle, sort_keys=False)

    print(f"Generated {output_path}")


if __name__ == "__main__":
    main()
