# Outputs útiles tras `tofu apply`. Se imprimen en consola y los puede leer
# Ansible para generar el inventory automáticamente.

output "master_ip" {
  description = "IP del nodo control-plane"
  value       = var.k3s_master.ip
}

output "worker_ips" {
  description = "IPs de los nodos worker"
  value       = [for w in var.k3s_workers : w.ip]
}

output "all_nodes" {
  description = "Mapa nombre -> IP de todos los nodos"
  value = merge(
    { (var.k3s_master.name) = var.k3s_master.ip },
    { for w in var.k3s_workers : w.name => w.ip }
  )
}

output "ssh_command_master" {
  description = "Comando para conectarse al master por SSH"
  value       = "ssh ${var.cluster_user}@${var.k3s_master.ip}"
}
