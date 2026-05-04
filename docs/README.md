# Documentación del homelab

| Documento | Para qué sirve |
|---|---|
| [setup.md](setup.md) | Guía completa de instalación desde cero. Léela primero. |
| [ansible-ops.md](ansible-ops.md) | Manual operativo de Ansible: añadir nodos, upgrade k3s, troubleshooting. |
| [monitoring-ops.md](monitoring-ops.md) | Manual operativo de Prometheus/Grafana/Loki: dashboards, queries, upgrade. |

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
