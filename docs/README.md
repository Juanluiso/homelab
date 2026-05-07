# Documentación del homelab

| Documento | Para qué sirve |
|---|---|
| [setup.md](setup.md) | Guía completa de instalación desde cero. Léela primero. |
| [ansible-ops.md](ansible-ops.md) | Manual operativo de Ansible: añadir nodos, upgrade k3s, troubleshooting. |
| [monitoring-ops.md](monitoring-ops.md) | Manual operativo de Prometheus/Grafana/Loki: dashboards, queries, upgrade. |
| [homepage-ops.md](homepage-ops.md) | Manual operativo de Homepage: añadir servicios, widgets, secrets, tema. |
| [uptime-kuma-ops.md](uptime-kuma-ops.md) | Manual operativo de Uptime Kuma: monitores, status page, notificaciones Telegram. |
| [cloudflared-ops.md](cloudflared-ops.md) | Manual operativo de Cloudflare Tunnel: quick tunnel, ver URL, migrar a named tunnel. |

## Si estás empezando

1. Lee `setup.md` entero.
2. Sigue los pasos hasta que tengas el cluster vivo.
3. Cuando algo falle o quieras cambiar, vuelve aquí a buscar el manual operativo correspondiente.

## Si vienes a buscar algo concreto

- "Quiero añadir un nodo" → [ansible-ops.md § Añadir un nodo nuevo](ansible-ops.md#añadir-un-nodo-nuevo)
- "Quiero ver logs de mi app en Grafana" → [monitoring-ops.md § LogQL](monitoring-ops.md#logql)
- "Cómo upgradear k3s" → [ansible-ops.md § Subir/bajar versión de k3s](ansible-ops.md#subirbajar-versión-de-k3s)
- "Cómo cambiar la retención de métricas" → [monitoring-ops.md § Cambiar retención](monitoring-ops.md#cambiar-retención)
- "Cómo activar alertas a Telegram" → [monitoring-ops.md § Activar Alertmanager](monitoring-ops.md#activar-alertmanager)
- "Quiero añadir un servicio al dashboard" → [homepage-ops.md § Añadir un servicio nuevo](homepage-ops.md#añadir-un-servicio-nuevo)
- "Cómo añadir credenciales a Homepage" → [homepage-ops.md § Añadir credenciales](homepage-ops.md#añadir-credenciales)
- "Generar token API de ArgoCD" → [homepage-ops.md § Token API de ArgoCD](homepage-ops.md#token-api-de-argocd)
- "Quiero monitorizar un servicio nuevo" → [uptime-kuma-ops.md § Añadir un monitor](uptime-kuma-ops.md#añadir-un-monitor)
- "Recibir alertas por Telegram" → [uptime-kuma-ops.md § Notificaciones a Telegram](uptime-kuma-ops.md#notificaciones-a-telegram)
- "Ver la URL pública del homelab" → [cloudflared-ops.md § Ver la URL pública actual](cloudflared-ops.md#ver-la-url-pública-actual)
- "Cambiar a qué servicio apunta el tunnel" → [cloudflared-ops.md § Cambiar a qué servicio apunta](cloudflared-ops.md#cambiar-a-qué-servicio-apunta)
- "Migrar a Named Tunnel cuando tenga dominio" → [cloudflared-ops.md § Migrar a Named Tunnel](cloudflared-ops.md#migrar-a-named-tunnel)
