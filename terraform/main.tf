resource "proxmox_vm_qemu" "kubernetes_node" {
  for_each = local.kubernetes_nodes

  name        = each.key
  description = "Kubernetes ${each.value.role} node managed by Terraform"
  target_node = coalesce(each.value.target_node, var.target_node)
  vmid        = each.value.vmid

  clone      = var.template_name
  full_clone = true

  agent   = 1
  os_type = "cloud-init"
  qemu_os = "l26"

  memory = each.value.memory

  cpu {
    cores   = each.value.cores
    sockets = 1
  }

  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
          storage = var.storage_pool
          discard = var.disk_discard
        }
      }
    }
  }

  network {
    id     = 0
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
