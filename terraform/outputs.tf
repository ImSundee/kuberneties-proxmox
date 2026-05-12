output "node_addresses" {
  description = "Kubernetes node IP addresses keyed by hostname."
  value = {
    for name, node in local.kubernetes_nodes : name => {
      role = node.role
      ip   = node.ip
    }
  }
}
