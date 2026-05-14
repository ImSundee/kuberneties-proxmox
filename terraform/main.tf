resource "proxmox_vm_qemu" "kubernetes_node" {
  for_each = local.kubernetes_nodes

  name        = each.key
  description = "Kubernetes ${each.value.role} node managed by Terraform"
  target_node = coalesce(each.value.target_node, var.target_node)
  vmid        = each.value.vmid

  clone      = var.template_name
  full_clone = var.full_clone

  agent   = 1
  os_type = "cloud-init"
  qemu_os = "l26"
  bios    = "ovmf"
  machine = "q35"

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
  ciupgrade    = false
  sshkeys      = var.ssh_public_key
  nameserver   = var.nameserver
  searchdomain = var.dns_domain
  ipconfig0    = "ip=${each.value.ip}/${each.value.cidr},gw=${var.gateway}"
  skip_ipv6    = true

  tags = "kubernetes;${each.value.role};terraform"
}
