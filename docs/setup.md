# Guía completa de setup — Homelab GitOps Stack

Esta guía documenta paso a paso cómo se construyó este homelab desde cero. Reproducible: cualquier persona con un Proxmox debería poder seguir estos pasos y acabar con un cluster k3s + ArgoCD funcional.

## Arquitectura final

```
┌──────────────────────────────────────────┐
│   GitHub: Juanluiso/homelab              │
└────────────────┬─────────────────────────┘
                 │ git push
                 ▼
   ┌──────────────────────────┐
   │   ArgoCD (en cluster)    │ ◄── lee continuamente
   └──────────────────────────┘
                 │ aplica
                 ▼
   ┌────────────────────────────────────┐
   │  k3s cluster (3 nodos)             │
   │  ├── master   192.168.1.110        │
   │  ├── worker-1 192.168.1.111        │
   │  └── worker-2 192.168.1.112        │
   └────────────────────────────────────┘
                 ▲
                 │ provisiona / configura
   ┌─────────────┴────────────────┐
   │  OpenTofu  +  cloud-init     │
   └──────────────────────────────┘
                 │
                 ▼
   ┌────────────────────────────────────┐
   │  Proxmox VE 9.1 @ 192.168.1.10     │
   │  Intel i5-8500T · 6c · 16 GB RAM   │
   └────────────────────────────────────┘
```

## Stack

| Componente | Versión | Función |
|---|---|---|
| Proxmox VE | 9.1.0 | Hipervisor |
| OpenTofu | 1.11.6 | Provisión IaC |
| bpg/proxmox provider | 0.66 | Talk to Proxmox API |
| Ubuntu cloud image | 22.04 LTS | OS de las VMs |
| cloud-init | - | Bootstrapping de VMs |
| k3s | v1.35.4 | Kubernetes ligero |
| ArgoCD | latest stable | GitOps controller |

## Fases del proyecto

### Fase 1 — Preparación de Proxmox

#### 1.1 Crear API token

Panel Proxmox web → **Datacenter → Permissions → API Tokens → Add**:
- User: `root@pam`
- Token ID: `terraform`
- Privilege Separation: ❌ (más simple para empezar)

⚠️ Guarda el secret UUID — solo se muestra una vez.

#### 1.2 Autorizar SSH key

Desde la shell del nodo Proxmox (panel web → tu nodo → Shell):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'TU_CLAVE_PUBLICA_AQUI' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 1.3 Crear template cloud-init

Ejecutar el script desde tu PC (vía SSH):

```bash
ssh root@192.168.1.10 "bash -s" < scripts/create-cloudinit-template.sh
```

Hace:
1. Descarga Ubuntu 22.04 cloud image (~600 MB)
2. Inyecta `qemu-guest-agent` con `virt-customize`
3. Crea VM con VMID 9000
4. Convierte a template

### Fase 2 — Provisión con OpenTofu

#### 2.1 Configurar variables locales

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars con tus valores reales (token secret, SSH key, IP gateway)
```

`terraform.tfvars` está en `.gitignore` — NUNCA se sube al repo.

#### 2.2 Inicializar y aplicar

```bash
tofu init       # descarga providers
tofu plan       # muestra qué va a hacer
tofu apply      # crea las 3 VMs (~1-2 min)
```

Outputs esperados:
```
master_ip          = "192.168.1.110"
worker_ips         = ["192.168.1.111", "192.168.1.112"]
ssh_command_master = "ssh juanlu@192.168.1.110"
```

#### 2.3 Verificar SSH a las VMs

```bash
for ip in 192.168.1.110 192.168.1.111 192.168.1.112; do
  ssh juanlu@$ip "hostname"
done
```

Debe responder con los hostnames correctos.

### Fase 3 — Instalar k3s

Por ahora vía SSH directo. Pendiente de migrar a Ansible (ver TODO.md).

#### 3.1 Master

```bash
ssh juanlu@192.168.1.110 \
  "curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC='--write-kubeconfig-mode 644 --tls-san 192.168.1.110' sh -"
```

#### 3.2 Obtener join token

```bash
K3S_TOKEN=$(ssh juanlu@192.168.1.110 "sudo cat /var/lib/rancher/k3s/server/node-token")
```

#### 3.3 Workers

```bash
for ip in 192.168.1.111 192.168.1.112; do
  ssh juanlu@$ip \
    "curl -sfL https://get.k3s.io | sudo K3S_URL=https://192.168.1.110:6443 K3S_TOKEN='$K3S_TOKEN' sh -"
done
```

#### 3.4 Bajar kubeconfig al PC

```bash
mkdir -p ~/.kube
ssh juanlu@192.168.1.110 "sudo cat /etc/rancher/k3s/k3s.yaml" \
  | sed 's/127.0.0.1/192.168.1.110/g' > ~/.kube/homelab-config
chmod 600 ~/.kube/homelab-config

export KUBECONFIG=~/.kube/homelab-config
kubectl get nodes
# 3 nodos en estado Ready
```

### Fase 4 — Instalar ArgoCD

#### 4.1 Bootstrap

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts
```

> Importante: `--server-side` es necesario porque el CRD `applicationsets.argoproj.io` excede el límite de 256 KB en annotations del apply tradicional.

#### 4.2 Esperar a que esté listo

```bash
kubectl -n argocd wait --for=condition=available deployment --all --timeout=300s
```

#### 4.3 Obtener password admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

⚠️ Cambia esta password tras el primer login.

#### 4.4 Acceder al UI

Para acceso local rápido:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Abre `https://localhost:8080` (acepta el cert self-signed). Login: `admin` / la password obtenida.

### Fase 5 — GitOps en marcha

#### 5.1 Crear primera Application

`manifests/argocd-apps/nginx-demo.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Juanluiso/homelab.git
    targetRevision: main
    path: manifests/apps/nginx-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Aplicar:

```bash
kubectl apply -f manifests/argocd-apps/nginx-demo.yaml
```

#### 5.2 Verificar

```bash
kubectl -n argocd get application nginx-demo
# NAME         SYNC STATUS   HEALTH STATUS
# nginx-demo   Synced        Healthy

kubectl -n nginx-demo get pods
# 2 pods Running
```

#### 5.3 Probar el flujo GitOps

```bash
# 1. Editar replicas en deployment.yaml: 2 → 3
# 2. git commit + git push
# 3. ArgoCD detecta el cambio en menos de 3 minutos (intervalo default)
# 4. Sincroniza automáticamente

# Para forzar sync inmediato:
kubectl -n argocd patch app nginx-demo --type merge \
  -p '{"operation": {"sync": {}}}'
```

## Operativa diaria

### Añadir una nueva app

1. Crea `manifests/apps/<nombre>/` con sus YAMLs (deployment, service, ingress…)
2. Crea `manifests/argocd-apps/<nombre>.yaml` (Application apuntando a la carpeta anterior)
3. `git add . && git commit -m "feat: add <nombre>" && git push`
4. `kubectl apply -f manifests/argocd-apps/<nombre>.yaml` (una sola vez)
5. ArgoCD se encarga de mantenerla sincronizada

### Acceso rápido al cluster

```bash
# Variable persistente en tu shell:
export KUBECONFIG=~/.kube/homelab-config
# o más cómodo:
alias hk='kubectl --kubeconfig ~/.kube/homelab-config'
```

### Apagar/encender el homelab

```bash
# Apagar limpio
for ip in 192.168.1.111 192.168.1.112 192.168.1.110; do
  ssh juanlu@$ip "sudo shutdown -h now"
done

# Encender desde Proxmox
ssh root@192.168.1.10 "qm start 110; qm start 111; qm start 112"
# (los VMIDs se asignan automáticamente, ver outputs de tofu)
```

### Destruir todo (rollback completo)

```bash
cd infra/terraform
tofu destroy   # elimina las 3 VMs

# El template (VMID 9000) se conserva, listo para volver a desplegar.
```

## Troubleshooting

### Una VM no levanta

```bash
ssh root@192.168.1.10 "qm status <VMID> && qm config <VMID>"
ssh root@192.168.1.10 "qm terminal <VMID>"  # consola serie
```

### k3s muestra nodos NotReady

```bash
ssh juanlu@<ip> "sudo systemctl status k3s-agent"
ssh juanlu@<ip> "sudo journalctl -u k3s-agent -n 50"
```

### ArgoCD Application en estado OutOfSync sin razón

```bash
kubectl -n argocd describe app <nombre>
# Mira los eventos al final
```

### Error CRD too large al instalar ArgoCD

Usa `--server-side --force-conflicts`. Es el caso documentado más arriba.

## Cómo entender este proyecto desde fuera

Para un reclutador/recruiter:

> Este repo demuestra capacidad de **construir desde cero infraestructura cloud-native** sobre hardware on-premise:
> - **IaC** con OpenTofu para provisión de VMs en Proxmox
> - **cloud-init** para configuración inicial automática
> - **k3s** como distribución Kubernetes ligera
> - **ArgoCD** implementando el patrón GitOps
> - **Repo público** con secretos correctamente excluidos

Las próximas iteraciones (ver TODO.md): ansibleizar, observabilidad con Prometheus+Grafana+Loki, exposición pública con Cloudflare Tunnel, secrets management con Vault.
