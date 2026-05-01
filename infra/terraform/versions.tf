# Versiones y providers requeridos.
# Usamos bpg/proxmox: provider moderno, mantenido activamente y con soporte
# nativo de cloud-init (mejor que el clásico Telmate/proxmox para automation).

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
