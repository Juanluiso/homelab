# Manual operativo — Cloudflare Tunnel (cloudflared)

Cómo gestionar el tunnel que expone servicios del homelab a Internet sin abrir puertos del router.

---

## Índice

1. [Estado actual: Quick Tunnel](#estado-actual-quick-tunnel)
2. [Ver la URL pública actual](#ver-la-url-pública-actual)
3. [Cambiar a qué servicio apunta](#cambiar-a-qué-servicio-apunta)
4. [Reiniciar el tunnel (URL nueva)](#reiniciar-el-tunnel)
5. [Migrar a Named Tunnel (con dominio)](#migrar-a-named-tunnel)
6. [Exponer varios servicios a la vez](#exponer-varios-servicios)
7. [Proteger los endpoints](#proteger-endpoints)
8. [Troubleshooting](#troubleshooting)

---

## Estado actual: Quick Tunnel

Hoy corremos `cloudflared` en modo **Quick Tunnel** (`--url ...`):

| Característica | Quick Tunnel | Named Tunnel |
|---|---|---|
| Necesita dominio | ❌ No | ✅ Sí |
| Necesita cuenta CF | ❌ No | ✅ Sí (gratis) |
| URL | `random-words.trycloudflare.com` | `subdominio.tudominio.com` |
| Persistente entre restarts | ❌ Cambia | ✅ Misma URL siempre |
| Production-ready | ❌ "best effort" | ✅ Sí |
| Auth Cloudflare Access | ❌ No | ✅ Sí (zero-trust) |
| Reglas de tráfico | ❌ No | ✅ Sí |

Quick Tunnel es perfecto para "necesito enseñar algo 5 minutos a un compañero". Para producción pasa a Named Tunnel cuando tengas dominio.

---

## Ver la URL pública actual

La URL aparece en los logs del pod cada vez que arranca:

```bash
export KUBECONFIG=~/.kube/homelab-config
kubectl -n cloudflared logs deploy/cloudflared | grep trycloudflare.com
```

Ejemplo de salida:

```
INF |  https://cheapest-par-reservation-sons.trycloudflare.com  |
```

### Atajo PowerShell

`tunnel.ps1`:

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
$url = (kubectl -n cloudflared logs deploy/cloudflared | Select-String "trycloudflare.com" | Select-Object -First 1)
Write-Host "URL pública: $url" -ForegroundColor Green
```

---

## Cambiar a qué servicio apunta

Edita `manifests/apps/cloudflared/deployment.yaml`:

```yaml
args:
  - tunnel
  - --no-autoupdate
  - --metrics
  - 0.0.0.0:2000
  - --url
  - http://homepage.homepage.svc.cluster.local:3000   # cambiar esto
```

Opciones útiles:

| Servicio | URL del cluster |
|---|---|
| Homepage | `http://homepage.homepage.svc.cluster.local:3000` |
| Uptime Kuma | `http://uptime-kuma.uptime-kuma.svc.cluster.local:3001` |
| Status page (sin auth) | `http://uptime-kuma.uptime-kuma.svc.cluster.local:3001/status/homelab` |
| Grafana | `http://kps-grafana.monitoring.svc.cluster.local` |
| ArgoCD | `https://argocd-server.argocd.svc.cluster.local` (cuidado: HTTPS interno self-signed) |

Tras editar:

```bash
git add . && git commit -m "feat(cloudflared): apuntar a uptime-kuma" && git push
```

ArgoCD aplica el cambio en su próximo poll. Y como el container args cambia, el pod se recrea automáticamente — saca la URL nueva con el comando del paso anterior.

> Para ArgoCD HTTPS interno con cert self-signed: añade `--no-tls-verify` a los args, o usa `https://...` con el flag `--http-host-header argocd-server.argocd.svc.cluster.local`.

---

## Reiniciar el tunnel

Para forzar una URL nueva (sin cambiar nada del config):

```bash
kubectl -n cloudflared rollout restart deploy cloudflared
sleep 10
kubectl -n cloudflared logs deploy/cloudflared | grep trycloudflare.com
```

---

## Migrar a Named Tunnel

Cuando compres dominio (`juanluismaldonado.dev` o similar) y lo metas en Cloudflare:

### 1. Crear el tunnel desde la UI de Cloudflare

1. <https://one.dash.cloudflare.com/> → Networks → Tunnels → Create a tunnel
2. Connector: Cloudflared
3. Nombre: `homelab`
4. Te da un **token** muy largo. Cópialo.

### 2. Configurar rutas en el dashboard

En el mismo wizard, añade hostnames:

- `argocd.tudominio.dev` → `https://argocd-server.argocd.svc.cluster.local:443` (No TLS Verify ON)
- `grafana.tudominio.dev` → `http://kps-grafana.monitoring.svc.cluster.local`
- `homepage.tudominio.dev` → `http://homepage.homepage.svc.cluster.local:3000`
- `status.tudominio.dev` → `http://uptime-kuma.uptime-kuma.svc.cluster.local:3001`

Cloudflare crea los CNAMEs en tu DNS automáticamente.

### 3. Crear el secret con el token

```bash
kubectl -n cloudflared create secret generic cloudflared-token \
  --from-literal=token="EL_TOKEN_LARGO"
```

### 4. Reemplazar el deployment por la versión "named"

```yaml
# manifests/apps/cloudflared/deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2024.10.0
          args:
            - tunnel
            - --no-autoupdate
            - run
            - --token
            - $(TUNNEL_TOKEN)
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflared-token
                  key: token
```

Push, ArgoCD aplica, y en segundos `argocd.tudominio.dev`, `grafana.tudominio.dev`, etc. funcionan con HTTPS automático.

---

## Exponer varios servicios

### Con Quick Tunnel
**Imposible**. Solo expone una URL. Hay que correr varios pods cloudflared, cada uno apuntando a un servicio distinto, y cada uno te da su URL random.

### Con Named Tunnel
**Trivial**. En el dashboard, un solo tunnel puede tener N hostnames apuntando a N servicios distintos. Es lo que harás cuando tengas dominio.

---

## Proteger endpoints

Hoy con Quick Tunnel **cualquiera con la URL accede**. Para añadir auth:

### Opción 1 — Cloudflare Access (con dominio + plan free)

En la UI de Zero Trust:
- Añade Application → Self-hosted → tu dominio
- Define policy: `email_domain == "juanluismaldonado.dev"` o lista de emails permitidos
- Cuando alguien va a `argocd.tudominio.dev`, Cloudflare le pide login (Google, GitHub, OTP por email)
- Si pasa, le deja entrar; si no, 403

Esto es **zero-trust gratis** sin tocar tu app.

### Opción 2 — IP allowlist en Cloudflare (con dominio)

WAF rules: bloquear todo excepto tu IP residencial / VPN. Útil para apps que solo abres tú.

### Opción 3 — Authentik / Authelia delante (sin dominio)

Self-hosted SSO en el cluster que protege todos los servicios. Más complejo de montar pero no necesita Cloudflare. Tema para otro día.

---

## Troubleshooting

### El pod arranca pero no aparece URL en logs

Revisa que el servicio destino existe:

```bash
kubectl get svc -A | grep -E "homepage|grafana|argocd"
```

Si la URL del `--url` no resuelve, cloudflared no consigue establecer el tunnel y no genera URL. Mira `kubectl -n cloudflared logs deploy/cloudflared` completo para ver el error.

### "Bad gateway" o "Origin connection error" al abrir la URL

cloudflared llega pero la app no responde. Comprueba:

```bash
kubectl exec -n cloudflared deploy/cloudflared -- wget -qO- http://homepage.homepage.svc:3000 | head -3
```

Si eso falla, el problema es interno al cluster (servicio caído, puerto malo, namespace mal escrito).

### URL funciona pero pide cert / 526 Invalid SSL

Cuando apuntas a HTTPS interno con cert self-signed (ArgoCD, Proxmox), añade:

```yaml
args:
  - tunnel
  - --no-autoupdate
  - --no-tls-verify       # añadir esto
  - --url
  - https://argocd-server.argocd.svc.cluster.local
```

### El tunnel se cae cada cierto tiempo

Quick Tunnel no garantiza uptime. Si te pasa frecuentemente, es síntoma de que necesitas Named Tunnel.

### "Connection limit reached"

Cloudflare limita conexiones por Quick Tunnel sin auth. Reinicia el pod para conseguir nueva conexión, o pasa a Named Tunnel.

---

## ¿Cuándo migrar al Named Tunnel?

Señales:

1. **Te toca enseñarlo a alguien por segunda vez** y la URL ya cambió → tener URL persistente vale el dominio.
2. **Quieres exponer 2+ servicios** → Named Tunnel lo hace en una sola conexión.
3. **Quieres añadir auth** → Cloudflare Access requiere dominio.
4. **Te preocupa el "uptime sin garantía"** del Quick Tunnel.

Hasta ese momento, Quick Tunnel sirve perfectamente para demos.
