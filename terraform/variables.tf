variable "proxmox_api_url" {
  description = "Proxmox API URL, for example https://pve.example.net:8006/api2/json."
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID."
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret."
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Allow self-signed Proxmox TLS certificates."
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Default Proxmox node where VMs are created unless overridden per node."
  type        = string
}

variable "template_name" {
  description = "Name of the Proxmox golden image template to clone."
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for VM disks."
  type        = string
}

variable "network_bridge" {
  description = "Proxmox bridge for Kubernetes node NICs."
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_key" {
  description = "SSH public key injected into Kubernetes nodes by cloud-init."
  type        = string
}

variable "cloud_init_user" {
  description = "User created or configured by cloud-init."
  type        = string
  default     = "debian"
}

variable "dns_domain" {
  description = "DNS search domain for Kubernetes nodes."
  type        = string
  default     = "cluster.local"
}

variable "nameserver" {
  description = "DNS resolver used by nodes."
  type        = string
}

variable "gateway" {
  description = "Default gateway for node IP configuration."
  type        = string
}

variable "control_plane_nodes" {
  description = "Control-plane node definitions keyed by hostname."
  type = map(object({
    vmid        = number
    ip          = string
    cidr        = number
    target_node = optional(string)
    cores       = optional(number, 2)
    memory      = optional(number, 4096)
    disk_size   = optional(string, "40G")
  }))
  default = {}
}

variable "worker_nodes" {
  description = "Worker node definitions keyed by hostname."
  type = map(object({
    vmid        = number
    ip          = string
    cidr        = number
    target_node = optional(string)
    cores       = optional(number, 4)
    memory      = optional(number, 8192)
    disk_size   = optional(string, "80G")
  }))
  default = {}
}
