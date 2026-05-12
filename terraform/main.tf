resource "proxmox_vm_qemu" "kubernetes_node" {
  for_each = local.kubernetes_nodes

  name        = each.key
  desc        = "Kubernetes ${each.value.role} node managed by Terraform"
  target_node = coalesce(each.value.target_node, var.target_node)
  vmid        = each.value.vmid

  clone      = var.template_name
  full_clone = true

  agent   = 1
  os_type = "cloud-init"
  qemu_os = "l26"

  cores   = each.value.cores
  sockets = 1
  memory  = each.value.memory

  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  ciuser       = var.cloud_init_user
  sshkeys      = var.ssh_public_key
  nameserver   = var.nameserver
  searchdomain = var.dns_domain
  ipconfig0    = "ip=${each.value.ip}/${each.value.cidr},gw=${var.gateway}"

  tags = "kubernetes;${each.value.role};terraform"
}
