# Homelab — Infrastructure as Code

Mi homelab Proxmox descrito enteramente en código: **OpenTofu/Terraform** provisiona las VMs, **Ansible** configura el SO, **k3s** corre como cluster Kubernetes y **ArgoCD** sincroniza aplicaciones desde este mismo repo (GitOps).

## Arquitectura

```
                    ┌──────────────────────────┐
                    │   GitHub (este repo)     │
                    └─────────────┬────────────┘
                                  │
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                           ▼
   infra/terraform/           ansible/                   manifests/
   (provisión)                (configuración)            (apps - GitOps)
        │                          │                           │
        └─────► Proxmox @ .10 ─────► k3s cluster   ◄─sync──  ArgoCD
                                    (3 nodos)
```

## Estructura

```
homelab/
├── infra/terraform/    # OpenTofu: provisión de VMs en Proxmox
├── ansible/            # Configuración de SO + instalación de k3s
├── manifests/          # GitOps - lo que ArgoCD aplica al cluster
│   ├── argocd/         # Bootstrap del propio ArgoCD
│   └── apps/           # Aplicaciones desplegadas
├── scripts/            # Helpers (creación de template cloud-init, etc.)
└── docs/               # Documentación adicional
```

## Stack

| Componente | Versión | Función |
|---|---|---|
| Proxmox VE | 9.x | Hipervisor |
| OpenTofu | 1.6+ | Provisión IaC |
| Ansible | 2.16+ | Configuration management |
| k3s | 1.30+ | Kubernetes ligero |
| ArgoCD | 2.13+ | GitOps controller |
| Cloudflare Tunnel | - | Exposición pública sin abrir puertos |

## Quick start

```bash
# 1. Crear template de cloud-init en Proxmox (una vez)
ssh root@192.168.1.10 < scripts/create-cloudinit-template.sh

# 2. Provisionar VMs
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars  # editar con tus valores
tofu init
tofu apply

# 3. Configurar nodos e instalar k3s
cd ../../ansible
ansible-playbook -i inventory.yml site.yml

# 4. Bootstrap ArgoCD
kubectl apply -k manifests/argocd

# 5. Deja que ArgoCD haga el resto
```

Documentación detallada en [docs/setup.md](docs/setup.md).

## Estado

Proyecto en construcción. Sigue el progreso en [GitHub Issues](https://github.com/Juanluiso/homelab/issues).

---

Hecho por [Juan Luis Maldonado](https://github.com/Juanluiso) como parte de su transición de sysadmin a DevOps.
