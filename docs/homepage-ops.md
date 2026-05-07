# Manual operativo — Homepage dashboard

Cómo usar y modificar el dashboard del homelab. Asume que ya está desplegado vía ArgoCD (`manifests/argocd-apps/homepage.yaml`).

---

## Índice

1. [Acceder al dashboard](#acceder-al-dashboard)
2. [Estructura de la config](#estructura-de-la-config)
3. [Añadir un servicio](#añadir-un-servicio-nuevo)
4. [Añadir un widget con datos en vivo](#añadir-un-widget)
5. [Añadir credenciales (Secret pattern)](#añadir-credenciales)
6. [Generar token API de ArgoCD](#token-api-de-argocd)
7. [Cambiar tema y colores](#tema-y-colores)
8. [Layout (filas/columnas)](#layout)
9. [Bookmarks](#bookmarks)
10. [Workflow: cambiar la config y desplegar](#workflow-gitops)
11. [Troubleshooting](#troubleshooting)

---

## Acceder al dashboard

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
kubectl -n homepage port-forward svc/homepage 3000:3000
```

Abrir `http://localhost:3000`.

### Atajo PowerShell

`hp.ps1`:

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
Write-Host "Homepage: http://localhost:3000" -ForegroundColor Green
kubectl -n homepage port-forward svc/homepage 3000:3000
```

---

## Estructura de la config

Toda la config vive en `manifests/apps/homepage/homepage-values.yaml`, sección `config`:

```yaml
config:
  bookmarks:    # enlaces favoritos abajo
  services:     # cards principales (con widgets opcionales)
  widgets:      # los widgets superiores (reloj, recursos, búsqueda)
  settings:     # tema, layout, título, etc.
  kubernetes:   # config del cliente k8s del widget
```

---

## Añadir un servicio nuevo

Edita `homepage-values.yaml` → `config.services`:

```yaml
services:
  - "Mi nueva sección":           # nuevo grupo
      - Mi App:
          href: http://miapp.svc.cluster.local
          description: Lo que hace mi app
          icon: nginx.svg          # iconos en https://gethomepage.dev/configs/services/#icons
          # opcional: widget si tu app expone una API
          # widget:
          #   type: prometheus
          #   url: http://prometheus...
```

Y luego sigue el [workflow GitOps](#workflow-gitops).

### Iconos disponibles

- **Selfhosted**: `name.svg` — de [walkxcode/dashboard-icons](https://github.com/walkxcode/dashboard-icons/tree/main/png) (1000+)
- **Simple Icons**: `si-name` — de [simpleicons.org](https://simpleicons.org)
- **Material Design**: `mdi-name-#hexcolor`
- **URL externa**: `https://example.com/icon.png`

Ejemplos:
```yaml
icon: proxmox.svg          # selfhosted
icon: si-cloudflare        # simple-icons
icon: mdi-server-#4ade80   # material design coloreado
```

---

## Añadir un widget

Los widgets cuelgan de un servicio (debajo de la card). Cada tipo necesita campos distintos. La doc completa: <https://gethomepage.dev/widgets/>

### Ejemplos

**Prometheus (sin auth)**
```yaml
widget:
  type: prometheus
  url: http://prometheus.monitoring.svc:9090
```

**Grafana (basic auth)**
```yaml
widget:
  type: grafana
  url: http://grafana.monitoring.svc
  username: "{{HOMEPAGE_VAR_GRAFANA_USERNAME}}"
  password: "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}"
```

**Proxmox (API token)**
```yaml
widget:
  type: proxmox
  url: https://192.168.1.10:8006
  username: "{{HOMEPAGE_VAR_PROXMOX_TOKEN_ID}}"
  password: "{{HOMEPAGE_VAR_PROXMOX_TOKEN_SECRET}}"
  node: proxmox
```

**ArgoCD (API token, ver más abajo)**
```yaml
widget:
  type: argocd
  url: https://argocd-server.argocd.svc.cluster.local
  key: "{{HOMEPAGE_VAR_ARGOCD_TOKEN}}"
```

**GitHub (PAT)**
```yaml
widget:
  type: githubprofilestats
  username: Juanluiso
  key: "{{HOMEPAGE_VAR_GITHUB_TOKEN}}"
```

---

## Añadir credenciales

Las credenciales NO van en el repo Git. Patrón:

### 1. Crear (o actualizar) el Secret en el cluster

```bash
kubectl -n homepage create secret generic homepage-credentials \
  --from-literal=HOMEPAGE_VAR_GITHUB_TOKEN="ghp_xxx" \
  --from-literal=HOMEPAGE_VAR_PROXMOX_TOKEN_ID="..." \
  --from-literal=HOMEPAGE_VAR_PROXMOX_TOKEN_SECRET="..." \
  --dry-run=client -o yaml | kubectl apply -f -
```

> Las claves DEBEN empezar por `HOMEPAGE_VAR_` para que Homepage las reconozca como sustituibles en `{{...}}`.

### 2. Verificar que el envFrom las inyecta

En `homepage-values.yaml` ya está:

```yaml
envFrom:
  - secretRef:
      name: homepage-credentials
```

### 3. Reiniciar el pod

```bash
kubectl -n homepage rollout restart deploy homepage
```

### 4. Referenciar la variable

```yaml
widget:
  type: githubprofilestats
  key: "{{HOMEPAGE_VAR_GITHUB_TOKEN}}"
```

> Importante: las comillas dobles `"..."` son obligatorias. Sin comillas, YAML interpreta `{{...}}` como sintaxis Helm y rompe.

---

## Token API de ArgoCD

ArgoCD v2.13+ no acepta basic auth en su API. El widget v1.2.0 de Homepage lo intenta y falla con 401. Solución: crear una cuenta local con permisos read-only y un API token persistente.

### Setup (una vez)

```bash
# Habilitar la cuenta 'homepage' con apiKey
kubectl -n argocd patch cm argocd-cm --type merge \
  -p '{"data":{"accounts.homepage":"apiKey","accounts.homepage.enabled":"true"}}'

# Permisos read-only
kubectl -n argocd patch cm argocd-rbac-cm --type merge \
  -p '{"data":{"policy.csv":"g, homepage, role:readonly\n"}}'

# Reiniciar argocd-server para que aplique
kubectl -n argocd rollout restart deploy argocd-server
kubectl -n argocd rollout status deploy/argocd-server
```

### Generar el token

```bash
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

kubectl -n homepage run curltest --rm -i --restart=Never --image=curlimages/curl -- \
  sh -c "
ADMIN=\$(curl -sk -X POST https://argocd-server.argocd.svc.cluster.local/api/v1/session \
  -H 'Content-Type: application/json' \
  -d '{\"username\":\"admin\",\"password\":\"$ARGOCD_PASS\"}' \
  | sed -E 's/.*\"token\":\"([^\"]+)\".*/\1/')

curl -sk -X POST https://argocd-server.argocd.svc.cluster.local/api/v1/account/homepage/token \
  -H \"Authorization: Bearer \$ADMIN\" -H 'Content-Type: application/json' -d '{}'
"
```

Copia el `token` de la respuesta.

### Guardar en el secret de Homepage

Añade `HOMEPAGE_VAR_ARGOCD_TOKEN=<token>` al Secret y reinicia el pod.

---

## Tema y colores

```yaml
settings:
  theme: dark             # dark / light
  color: slate            # slate, gray, zinc, neutral, stone, red, orange, amber, yellow,
                          # lime, green, emerald, teal, cyan, sky, blue, indigo, violet,
                          # purple, fuchsia, pink, rose, white
  iconStyle: theme        # theme / gradient
  fiveColumns: true       # filas más anchas
  hideVersion: true       # esconder número de versión abajo
  language: es            # i18n
  background:
    image: https://...    # imagen de fondo (URL)
    blur: sm              # sm / md / xl / 2xl / 3xl
    saturate: 50          # 0-200
    brightness: 75        # 0-200
    opacity: 50           # 0-100
```

---

## Layout

```yaml
settings:
  layout:
    "Infraestructura":
      style: row
      columns: 4
      icon: mdi-server-#4ade80
      header: true
    "Apps":
      style: row
      columns: 3
    "Externos":
      style: column        # vertical
```

`style: row` mete las cards en columnas (grid). `style: column` apila verticalmente. `columns: N` controla cuántas por fila.

---

## Bookmarks

Enlaces planos abajo, agrupados por categoría:

```yaml
bookmarks:
  - Developer:
      - GitHub:
          - abbr: GH         # las dos letras del icono
            href: https://github.com/Juanluiso
      - Docs:
          - abbr: K8s
            href: https://kubernetes.io/docs/
```

---

## Workflow GitOps

Cualquier cambio sigue el mismo flujo:

```bash
# 1. Editar
vim manifests/apps/homepage/homepage-values.yaml

# 2. Commit
git add . && git commit -m "feat(homepage): añadir Pi-hole" && git push

# 3. ArgoCD detecta el cambio en su próximo poll (~3 min).
#    Para forzar inmediato:
kubectl -n argocd patch app homepage --type merge -p '{"operation": {"sync": {}}}'

# 4. (Opcional) Reinicia el pod si los cambios son de envvar/secret:
kubectl -n homepage rollout restart deploy homepage
```

> Los cambios en `config.services` / `config.widgets` no necesitan rollout — Homepage los lee del ConfigMap montado y se actualizan en caliente. **Solo** los cambios en envvars (Secret) requieren rollout.

---

## Troubleshooting

### Una tarjeta muestra "API Error" o "Loading..." indefinidamente

```bash
kubectl -n homepage logs deploy/homepage --tail=50 | grep -iE "error|fail"
```

Errores típicos:
- **401 Unauthorized** → credenciales mal o widget que no soporta basic auth (caso ArgoCD)
- **HTTP Error 0** → no resuelve la URL. Comprueba que el Service existe.
- **HTTP Error 7** → no puede conectar (HTTPS roto, puerto cerrado).

### El widget no aparece (la tarjeta sale como simple enlace)

- Verifica indentación: `widget:` debe estar al MISMO nivel que `href:`/`icon:`, NO dentro de `description:`.
- Verifica que el `type:` existe en la doc de Homepage.

### Secret no se inyecta tras editar

```bash
# Verificar contenido del secret
kubectl -n homepage get secret homepage-credentials -o json | jq -r '.data | keys'

# Verificar que el pod ve el envvar
kubectl -n homepage exec deploy/homepage -- printenv | grep HOMEPAGE_VAR_

# Si no las ve, reinicia
kubectl -n homepage rollout restart deploy homepage
```

### El icono no carga

Iconos `name.svg` requieren que existan en el repo de [dashboard-icons](https://github.com/walkxcode/dashboard-icons). Comprueba ahí. Si no está, usa `si-name` (Simple Icons) o una URL externa.

### Widget de Kubernetes vacío

Necesita RBAC. En el chart está `enableRbac: true`. Verifica:

```bash
kubectl get clusterrolebinding | grep homepage
```

### "fiveColumns" no se aplica

Está documentado pero solo afecta a algunas resoluciones. Para forzar más columnas, usa `layout.<grupo>.columns: 5`.
