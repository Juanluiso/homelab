# Manual operativo — Ansible

Cómo usar el setup de Ansible del día a día. Asume que ya leíste [setup.md](setup.md) y entiendes la estructura.

---

## Índice

1. [Ejecutar el playbook](#ejecutar-el-playbook)
2. [Añadir un nodo nuevo al cluster](#añadir-un-nodo-nuevo)
3. [Subir/bajar versión de k3s](#subirbajar-versión-de-k3s)
4. [Quitar un nodo del cluster](#quitar-un-nodo)
5. [Añadir un paquete a todos los nodos](#añadir-un-paquete)
6. [Añadir una nueva tarea](#añadir-una-nueva-tarea)
7. [Crear un rol nuevo desde cero](#crear-un-rol-nuevo)
8. [Probar antes de aplicar (dry-run)](#dry-run)
9. [Limitar a un grupo o host](#limitar-ejecución)
10. [Troubleshooting](#troubleshooting)

---

## Ejecutar el playbook

Desde la carpeta `ansible/` del repo:

```bash
./run.sh                       # corre site.yml entero
./run.sh -m ping all           # ad-hoc ping a todos los hosts
./run.sh -m setup --limit master   # gather facts del master
```

El wrapper `run.sh` arranca un contenedor Docker con Ansible y monta tu SSH key con permisos correctos.

---

## Añadir un nodo nuevo

Tres pasos:

### 1. Provisionar la VM con OpenTofu

Edita `infra/terraform/variables.tf` o `terraform.tfvars`:

```hcl
k3s_workers = [
  # ...los existentes...
  {
    name = "k3s-worker-3"
    cpu = 2; memory = 2048; disk_gb = 20
    ip = "192.168.1.113"
  }
]
```

```bash
cd infra/terraform && tofu apply
```

### 2. Añadir al inventory de Ansible

`ansible/inventory.yml`:

```yaml
k3s_agent:
  hosts:
    k3s-worker-1: { ansible_host: 192.168.1.111 }
    k3s-worker-2: { ansible_host: 192.168.1.112 }
    k3s-worker-3: { ansible_host: 192.168.1.113 }   # nuevo
```

### 3. Aplicar

```bash
cd ansible && ./run.sh
```

Por idempotencia, Ansible **no toca** los nodos existentes. Solo configura el nuevo y lo une al cluster.

---

## Subir/bajar versión de k3s

Edita `ansible/group_vars/all.yml`:

```yaml
k3s_version: "v1.31.5+k3s1"   # versión nueva
```

Y aplica:

```bash
./run.sh
```

El rol `k3s_server` detecta que la versión instalada (en `k3s --version`) no coincide con la deseada y reinstala. Idem para `k3s_agent`.

> **Cuidado**: Kubernetes recomienda no saltarse minor versions. De 1.30 a 1.31 OK, no de 1.30 a 1.33 directo. Lee siempre las release notes de k3s.

---

## Quitar un nodo

### 1. Cordon + drain en Kubernetes (importante)

Antes de borrarlo, mueve sus pods a otros nodos:

```bash
export KUBECONFIG=~/.kube/homelab-config
kubectl cordon k3s-worker-3                 # marca como "no programar más pods"
kubectl drain k3s-worker-3 --ignore-daemonsets --delete-emptydir-data
kubectl delete node k3s-worker-3            # elimina del API
```

### 2. Quitar la VM con OpenTofu

Eliminas la entrada del array `k3s_workers` en variables.tf y:

```bash
tofu apply
```

### 3. Quitar del inventory de Ansible

Borrar la línea correspondiente en `inventory.yml`. Ya no es necesario aplicar nada.

---

## Añadir un paquete

Edita `ansible/group_vars/all.yml`:

```yaml
common_packages:
  - curl
  - htop
  - net-tools
  - vim
  - ca-certificates
  - tmux        # nuevo
  - jq          # nuevo
```

Y `./run.sh`. Como el rol `common` corre en todos los nodos, se instalará en los 3.

---

## Añadir una nueva tarea

Las tareas viven en `roles/<rol>/tasks/main.yml`. Por ejemplo, para añadir una tarea al rol `common` que asegure que `unattended-upgrades` está activo:

```yaml
# ansible/roles/common/tasks/main.yml
- name: Asegurar unattended-upgrades activo
  ansible.builtin.systemd:
    name: unattended-upgrades
    state: started
    enabled: true
```

Y `./run.sh`.

---

## Crear un rol nuevo

Estructura mínima:

```bash
mkdir -p roles/mi_rol/{tasks,handlers,templates,defaults,vars}
echo "---" > roles/mi_rol/tasks/main.yml
```

Lo invocas desde `site.yml`:

```yaml
- name: Aplicar mi rol nuevo
  hosts: k3s_cluster
  become: true
  roles: [mi_rol]
```

---

## Dry-run

Para ver qué cambiaría sin aplicar:

```bash
./run.sh ansible-playbook -i inventory.yml site.yml --check --diff
```

(Como wrapper sólo invoca `ansible` por defecto, para playbook completo en check mode hay que pasarlo todo entero).

Mejor aún, ejecutas directamente con docker:

```bash
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "/c/Users/juaml/.ssh:/ssh-host:ro" \
  -v "$(pwd):/work" -w /work \
  -e ANSIBLE_HOST_KEY_CHECKING=False \
  cytopia/ansible:latest-tools \
  sh -c "mkdir -p /root/.ssh && cp /ssh-host/id_ed25519 /root/.ssh/ && chmod 600 /root/.ssh/id_ed25519 \
    && ansible-playbook -i inventory.yml site.yml --check --diff"
```

`--check`: nada se modifica, solo se simula.
`--diff`: muestra el contenido que cambiaría en archivos.

---

## Limitar ejecución

```bash
# Solo el master
./run.sh ansible-playbook -i inventory.yml site.yml --limit k3s_server

# Solo un worker
./run.sh ansible-playbook -i inventory.yml site.yml --limit k3s-worker-1

# Solo tareas con tag concreto (si las hubieras taggeado)
./run.sh ansible-playbook -i inventory.yml site.yml --tags packages
```

---

## Troubleshooting

### "Bad owner or permissions on /root/.ssh/id_ed25519"

El bind mount Windows abre permisos. Por eso el wrapper copia la key dentro del contenedor con chmod 600. Si bypaseas el wrapper, recuerda:

```bash
docker run ... cytopia/ansible sh -c "
  cp /ssh-host/id_ed25519 /root/.ssh/ && chmod 600 /root/.ssh/id_ed25519 && ...
"
```

### "the working directory '/work' is invalid"

Git Bash convierte automáticamente paths absolutos. Solución: prefijar con `MSYS_NO_PATHCONV=1`:

```bash
MSYS_NO_PATHCONV=1 docker run ...
```

### "Ansible is being run in a world writable directory"

Volume Windows monta con permisos abiertos → Ansible ignora `ansible.cfg`. Pasa el inventory explícitamente con `-i inventory.yml`. Es lo que hace el wrapper.

### "No se ha obtenido el token del master"

Estás corriendo `roles/k3s_agent` sin que `k3s_server` haya corrido en la misma run. Usa `site.yml` completo, no fases sueltas.

### Timeout esperando al API server

El servicio k3s no arrancó. SSH al master y mira:
```bash
sudo systemctl status k3s
sudo journalctl -u k3s -n 100
```

### Ansible se queda colgado en "Gathering Facts"

Probablemente DNS lento en la VM. Comprueba `/etc/resolv.conf` o usa `gather_facts: false` puntualmente.
