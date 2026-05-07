# Manual operativo — Uptime Kuma

Cómo usar Uptime Kuma para monitorear servicios y publicar la status page.

---

## Índice

1. [Acceder a la UI](#acceder-a-la-ui)
2. [Acceder a la status page pública](#status-page-pública)
3. [Añadir un monitor nuevo](#añadir-un-monitor)
4. [Tipos de monitor útiles](#tipos-de-monitor)
5. [Crear / editar status page](#crear--editar-status-page)
6. [Notificaciones a Telegram](#notificaciones-a-telegram)
7. [Notificaciones a Discord / Email](#notificaciones-a-discord--email)
8. [Backup de la base de datos](#backup-de-la-base-de-datos)
9. [Upgrade de versión](#upgrade-de-versión)
10. [Troubleshooting](#troubleshooting)

---

## Acceder a la UI

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
kubectl -n uptime-kuma port-forward svc/uptime-kuma 3001:3001
```

Abre `http://localhost:3001`. Login con la cuenta admin que creaste en el primer arranque.

### Atajo PowerShell

`kuma.ps1`:

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
Write-Host "Uptime Kuma: http://localhost:3001" -ForegroundColor Green
kubectl -n uptime-kuma port-forward svc/uptime-kuma 3001:3001
```

---

## Status page pública

Mientras esté configurada con slug `homelab`:

- **Desde tu LAN:** `http://localhost:3001/status/homelab` (con port-forward activo)
- **Desde dentro del cluster:** `http://uptime-kuma.uptime-kuma.svc:3001/status/homelab`

> Para hacerla pública en Internet → necesitarás Cloudflare Tunnel o Ingress + dominio (pendiente en TODO.md).

---

## Añadir un monitor

UI → botón verde **"Add New Monitor"** arriba a la izquierda. Campos clave:

- **Friendly Name:** lo que verá el usuario en la status page
- **Monitor Type:** ver tabla más abajo
- **URL / Hostname:** según el tipo
- **Heartbeat Interval:** 60s default es razonable para homelab
- **Retries:** 3 está bien (evita falsos positivos)
- **Tags:** ej. `infra`, `público` — útil para filtrar
- **Notifications:** elige las que aplican

---

## Tipos de monitor

| Tipo | Cuándo usarlo | Ejemplo |
|---|---|---|
| **HTTP(s)** | webapps, APIs públicas | `https://cv.juamluisms.workers.dev` |
| **HTTP(s) - Keyword** | webapps con respuestas variables | URL + keyword `Argo` (busca "Argo" en HTML) |
| **HTTP(s) - JSON Query** | APIs con health endpoint que devuelve JSON | URL + JSONata `$.status = "ok"` |
| **TCP Port** | servicios que no son HTTP | k3s API en `192.168.1.110:6443` |
| **Ping** | nodos sueltos | `192.168.1.110` |
| **DNS** | comprobar si el DNS resuelve | `cv.juamluisms.workers.dev` |
| **Docker Container** | contenedores en host con Docker | requiere socket /var/run/docker.sock |
| **Push** | servicios que llaman a Kuma (cron, batch jobs) | URL push en Kuma → tu cron hace `curl` |

### Para servicios HTTPS internos con cert self-signed

ArgoCD, Proxmox, Grafana sirven HTTPS con cert auto-firmado.

- Marca **"Ignore TLS/SSL Errors"** en el monitor
- O usa **HTTP** en lugar de HTTPS si el servicio expone HTTP también (Grafana, Prometheus)

### Truco para apps detrás de port-forward

No funcionan bien (el port-forward solo lo tienes tú). En su lugar usa el **Service ClusterIP DNS** desde dentro del cluster: Uptime Kuma vive en el mismo cluster, así que puede llegar directamente:

```
http://argocd-server.argocd.svc.cluster.local
http://kps-grafana.monitoring.svc.cluster.local
http://homepage.homepage.svc.cluster.local:3000
```

---

## Crear / editar status page

UI → menú izquierdo → **Status Pages** → **New Status Page** o icono lápiz para editar.

Campos importantes:

- **Slug:** lo que va al final de `/status/<slug>`. `homelab` está bien.
- **Title** + **Description**
- **Theme:** dark / light / auto
- **Footer text:** opcional, mensaje custom abajo
- **Show certificate expiry:** muestra días restantes del cert SSL (útil para detectar expiraciones)
- **Domain Names:** dominios bajo los que se sirve (importante si la expones públicamente)

### Agrupar monitores

En la edición de la status page → arrastra los monitores a grupos:

- **Apps públicas** — CV, Rajoyle
- **Infra** — Proxmox, k3s API, ArgoCD, Grafana, Prometheus, Loki
- **Apps internas** — Homepage, Status

> Una vez configurada, **publish**. La página se sirve sin auth.

---

## Notificaciones a Telegram

Lo más rápido y útil: cuando algo se cae, te llega al móvil.

### 1. Crear el bot

1. En Telegram, busca [@BotFather](https://t.me/BotFather)
2. Comando `/newbot`
3. Sigue las preguntas (nombre + username acabado en `bot`, ej. `juanlu_homelab_bot`)
4. BotFather te da un **HTTP API token** del tipo `123456789:AAH...` — guárdalo

### 2. Sacar tu chat_id

1. Manda **cualquier mensaje** a tu bot en Telegram (búscalo por su username)
2. Abre en navegador: `https://api.telegram.org/bot<TOKEN>/getUpdates`
3. En el JSON busca `"chat":{"id":123456789,...}` — ese número es tu `chat_id`

### 3. Configurar en Uptime Kuma

UI → **Settings → Notifications → Setup notification**:

- **Notification Type:** Telegram
- **Friendly Name:** `Telegram personal`
- **Bot Token:** el que te dio BotFather
- **Chat ID:** el de getUpdates
- **Test** → debes recibir un mensaje en Telegram
- **Save** → marca "Apply on All Existing Monitors" si quieres aplicarla a todos

### Resultado

Cuando un monitor pasa de UP a DOWN, te llega:

```
🔴 [Down] Grafana
The monitor 'Grafana' is down: HTTP code 500
Time: 2026-05-08 03:42:11
```

Y otro mensaje cuando vuelve a UP. Mucho más útil que mirar dashboards.

---

## Notificaciones a Discord / Email

### Discord

1. En tu servidor Discord → ajustes del canal → **Integrations → Webhooks → New Webhook**
2. Copia la **Webhook URL**
3. En Kuma → Notifications → Discord → pega la URL → Test

### Email SMTP

Necesitas servidor SMTP (Gmail con app password, ProtonMail Bridge, etc.):

- **Hostname:** `smtp.gmail.com`
- **Port:** `587`
- **Secure:** STARTTLS
- **Username + Password:** las credenciales SMTP
- **From:** tu email
- **To:** dónde recibirlas

---

## Backup de la base de datos

Toda la config (monitores, status pages, notificaciones, historial de incidencias) vive en **SQLite** dentro del PVC. Backup:

```bash
export KUBECONFIG=~/.kube/homelab-config
POD=$(kubectl -n uptime-kuma get pods -l app=uptime-kuma -o jsonpath='{.items[0].metadata.name}')
kubectl -n uptime-kuma cp $POD:/app/data/kuma.db ./kuma-$(date +%Y%m%d).db
```

Restore (si haces redeploy y quieres traer la BD a otro PVC):

```bash
kubectl -n uptime-kuma cp ./kuma-20260508.db $POD:/app/data/kuma.db
kubectl -n uptime-kuma rollout restart deploy uptime-kuma
```

> Cuando montemos Velero (en TODO.md), el PVC se respaldará automáticamente.

---

## Upgrade de versión

El deployment fija la imagen a `louislam/uptime-kuma:1.23.16-alpine`. Para subirla:

1. Mira la última en <https://github.com/louislam/uptime-kuma/releases>
2. Edita `manifests/apps/uptime-kuma/deployment.yaml`:
   ```yaml
   image: louislam/uptime-kuma:1.24.0-alpine
   ```
3. `git add . && git commit -m "chore: uptime-kuma 1.24.0" && git push`
4. ArgoCD aplica el cambio. Strategy `Recreate` apaga el pod viejo, monta el PVC al nuevo.

> **Antes de upgrade**: haz backup de la BD por si rompe migración (sección anterior).

---

## Troubleshooting

### Un monitor está en "Pending"

- Aún no ha hecho el primer check. Espera 1 minuto.
- Si tras ello sigue: revisa la URL/host. UI → click en el monitor → **History** para ver los errores.

### Falsos positivos (DOWN cuando está UP)

- Sube **Retries** a 5 y **Heartbeat Interval** a 90s
- Si es HTTP, comprueba que la web responde 200 (no 301/302 sin destino)
- Si es TCP, comprueba con `nc -zv host port` desde otro nodo

### Status page muestra un servicio sin barra de uptime

Falta historial. Espera unos minutos a que recoja datos.

### "Cannot read properties of undefined" en la status page

Bug conocido cuando borras un monitor que estaba en una status page sin quitarlo antes. Edita la status page → quita el monitor fantasma → save.

### El pod no arranca tras un upgrade

Probablemente la BD se rompió en una migración fallida. Restaura el backup más reciente (sección Backup).

### Quiero exponer la status page a Internet

Hoy es interna (`status/homelab` solo accesible vía port-forward / desde el cluster). Para hacerla pública:

- **Cloudflare Tunnel** (pendiente en TODO.md): exposición sin abrir puertos.
- **Ingress + cert-manager** (pendiente): si tuvieras dominio apuntando a tu IP pública (no recomendado en homelab residencial).
