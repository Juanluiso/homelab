# Configuración del provider Proxmox.
# Las credenciales NUNCA están en este archivo: vienen de variables (terraform.tfvars
# o variables de entorno PM_*). El archivo terraform.tfvars está en .gitignore.

provider "proxmox" {
  endpoint = var.proxmox_endpoint

  # Autenticación por API token (no usamos password).
  # Formato: "USER@REALM!TOKENID=SECRET"
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"

  insecure = var.proxmox_insecure  # true si tu Proxmox usa cert self-signed

  # Para algunas operaciones (subir snippets cloud-init) bpg/proxmox necesita SSH.
  ssh {
    agent       = false
    username    = "root"
    private_key = file(var.ssh_private_key_path)
  }
}
