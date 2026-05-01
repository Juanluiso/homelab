# Ansible — Configuración y k3s install

Tres roles que configuran las VMs ya provisionadas por OpenTofu y montan el cluster k3s.

## Estructura

```
ansible/
├── ansible.cfg            # config: pipelining, etc.
├── inventory.yml          # 3 hosts fijos (master + 2 workers)
├── site.yml               # playbook principal (orquesta los 3 roles)
├── group_vars/
│   └── all.yml            # versión k3s, IP del server, paquetes
└── roles/
    ├── common/            # paquetes base, sysctl, qemu-agent
    ├── k3s_server/        # instala k3s server, lee token
    └── k3s_agent/         # instala agent, lo une con el token
```

## Cómo se ejecuta

### Opción A — Docker (sin instalar Ansible localmente)

Desde la carpeta `ansible/`:

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $PWD:/work -w /work \
  cytopia/ansible:latest-tools \
  ansible-playbook site.yml
```

En PowerShell (Windows) sustituye `$PWD` por `${PWD}`.

### Opción B — Ansible local (Linux/Mac/WSL)

```bash
pip install ansible
cd ansible
ansible-playbook site.yml
```

## Idempotencia

Los roles están escritos para **detectar si k3s ya está instalado** y no reinstalarlo. Pasar el playbook sobre un cluster ya operativo es seguro: solo verifica el estado y termina.

Para forzar reinstalación completa, primero desinstala manualmente con `k3s-uninstall.sh` (master) o `k3s-agent-uninstall.sh` (workers).

## Ciclo completo desde cero

```bash
# 1. Provisionar VMs
cd ../infra/terraform && tofu apply

# 2. Configurar y montar k3s
cd ../../ansible && docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro -v $PWD:/work -w /work \
  cytopia/ansible:latest-tools ansible-playbook site.yml

# 3. Bajar kubeconfig (manual de momento)
ssh juanlu@192.168.1.110 "sudo cat /etc/rancher/k3s/k3s.yaml" \
  | sed 's/127.0.0.1/192.168.1.110/g' > ~/.kube/homelab-config
```

## Troubleshooting

**"No se ha obtenido el token del master"** — Estás corriendo solo el role `k3s_agent` sin haber ejecutado `k3s_server` antes en la misma run. Usa siempre `site.yml` o limita con tags.

**Timeout esperando a que el API server responda** — El servicio k3s no arrancó bien. SSH al master y mira `journalctl -u k3s -n 50`.
