locals {
  kubernetes_nodes = merge(
    {
      for name, node in var.control_plane_nodes : name => merge(node, { role = "control-plane" })
    },
    {
      for name, node in var.worker_nodes : name => merge(node, { role = "worker" })
    }
  )
}
