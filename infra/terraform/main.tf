# =====================================================================
# Crea las 3 VMs del cluster k3s clonando el template cloud-init.
# - 1 master (control plane)
# - 2 workers
# Cada VM se configura con cloud-init: usuario sudo, SSH key, IP estática.
# =====================================================================

# Búsqueda del template por nombre, así no hardcodeamos el VMID
data "proxmox_virtual_environment_vms" "template" {
  filter {
    name   = "name"
    values = [var.template_name]
  }
}

locals {
  template_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
}

# ---------- Master ----------
resource "proxmox_virtual_environment_vm" "k3s_master" {
  name      = var.k3s_master.name
  node_name = var.proxmox_node
  tags      = ["k3s", "control-plane", "terraform"]

  clone {
    vm_id = local.template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.k3s_master.cpu
    type  = "host"
  }

  memory {
    dedicated = var.k3s_master.memory
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = var.k3s_master.disk_gb
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_pool

    ip_config {
      ipv4 {
        address = "${var.k3s_master.ip}/24"
        gateway = var.network_gateway
      }
    }

    user_account {
      username = var.cluster_user
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = var.dns_servers
    }
  }

  operating_system {
    type = "l26"  # Linux 2.6+
  }

  serial_device {}  # consola serie para troubleshooting

  lifecycle {
    ignore_changes = [initialization]  # evita recrear si cambia user-data
  }
}

# ---------- Workers ----------
resource "proxmox_virtual_environment_vm" "k3s_worker" {
  for_each = { for w in var.k3s_workers : w.name => w }

  name      = each.value.name
  node_name = var.proxmox_node
  tags      = ["k3s", "worker", "terraform"]

  clone {
    vm_id = local.template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = each.value.disk_gb
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_pool

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.network_gateway
      }
    }

    user_account {
      username = var.cluster_user
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = var.dns_servers
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [initialization]
  }
}
