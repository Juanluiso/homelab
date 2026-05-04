# =====================================================================
# Variables de entrada. Sus valores reales viven en terraform.tfvars
# (que está en .gitignore para no exponer secretos).
# =====================================================================

# ---------- Proxmox ----------
variable "proxmox_endpoint" {
  description = "URL del API Proxmox, ej: https://192.168.1.10:8006/"
  type        = string
}

variable "proxmox_token_id" {
  description = "Token ID en formato user@realm!nombre. Ej: root@pam!terraform"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Secret UUID del API token. Sensible: NUNCA en git."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "true si tu Proxmox usa certificado self-signed (lo normal en homelabs)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Nombre del nodo Proxmox donde se crean las VMs (ver panel)"
  type        = string
  default     = "proxmox"
}

# ---------- SSH ----------
variable "ssh_private_key_path" {
  description = "Ruta a la clave SSH privada que usa Terraform para conectarse"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_public_key" {
  description = "Clave SSH pública que se inyecta en las VMs vía cloud-init"
  type        = string
}

# ---------- Storage ----------
variable "storage_pool" {
  description = "ID del storage para discos de VM (típicamente 'local-lvm')"
  type        = string
  default     = "local-lvm"
}

variable "snippet_storage" {
  description = "Storage que admite snippets para cloud-init user-data"
  type        = string
  default     = "local"
}

# ---------- Template ----------
variable "template_name" {
  description = "Nombre del template cloud-init que crearemos previamente"
  type        = string
  default     = "ubuntu-2204-cloudinit"
}

# ---------- Red ----------
variable "network_bridge" {
  description = "Bridge de Proxmox (típicamente vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Gateway de la red (router)"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers para las VMs"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

# ---------- Cluster ----------
variable "cluster_user" {
  description = "Usuario que se creará en cada VM (no usamos root)"
  type        = string
  default     = "juanlu"
}

variable "k3s_master" {
  description = "Configuración del nodo control-plane"
  type = object({
    name     = string
    cpu      = number
    memory   = number  # en MB
    disk_gb  = number
    ip       = string
  })
  default = {
    name     = "k3s-master"
    cpu      = 2
    memory   = 4096      # 2 GB se queda corto con ArgoCD + observability
    disk_gb  = 20
    ip       = "192.168.1.110"
  }
}

variable "k3s_workers" {
  description = "Lista de nodos worker"
  type = list(object({
    name     = string
    cpu      = number
    memory   = number
    disk_gb  = number
    ip       = string
  }))
  default = [
    {
      name     = "k3s-worker-1"
      cpu      = 2
      memory   = 2048
      disk_gb  = 20
      ip       = "192.168.1.111"
    },
    {
      name     = "k3s-worker-2"
      cpu      = 2
      memory   = 2048
      disk_gb  = 20
      ip       = "192.168.1.112"
    }
  ]
}
