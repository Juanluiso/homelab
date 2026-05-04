# Manual operativo — Stack de observabilidad

Cómo usar Prometheus + Grafana + Loki en el día a día. Asume que ya está instalado (ver `manifests/apps/monitoring/README.md`).

---

## Índice

1. [Acceder a Grafana](#acceder-a-grafana)
2. [Cambiar la password de admin](#cambiar-la-password)
3. [Ver dashboards prebuilt](#dashboards-prebuilt)
4. [Crear un dashboard nuevo](#crear-un-dashboard-nuevo)
5. [PromQL — consultas comunes](#promql-básico)
6. [LogQL — buscar en Loki](#logql)
7. [Activar Alertmanager](#activar-alertmanager)
8. [Cambiar retención de datos](#cambiar-retención)
9. [Actualizar el chart (helm upgrade)](#upgrade-del-chart)
10. [Acceder a Prometheus directo](#acceder-a-prometheus)
11. [Troubleshooting](#troubleshooting)

---

## Acceder a Grafana

Port-forward desde tu PC:

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

Luego: `http://localhost:3000`
- **Usuario:** `admin`
- **Password:** `homelab-admin` (definida en `kube-prometheus-stack-values.yaml`)

> **No cierres la terminal** mientras uses Grafana — al cerrar el túnel se corta.

### Atajo PowerShell

Crea `grafana.ps1`:

```powershell
$env:KUBECONFIG = "$HOME\.kube\homelab-config"
Write-Host "Grafana: http://localhost:3000  (admin / homelab-admin)" -ForegroundColor Green
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

Y lo lanzas con `.\grafana.ps1`.

---

## Cambiar la password

### Vía UI (recomendado)
1. Login con `admin / homelab-admin`
2. Avatar abajo izquierda → **Profile**
3. **Change password**

### Vía CLI (si la pierdes)

```bash
export KUBECONFIG=~/.kube/homelab-config
kubectl -n monitoring exec deploy/kps-grafana -- \
  grafana-cli admin reset-admin-password "TU-NUEVA"
```

---

## Dashboards prebuilt

Tras instalar viene cargados, en **Dashboards → Browse**:

| Dashboard | Para qué sirve |
|---|---|
| Kubernetes / Compute Resources / Cluster | Vista global: CPU, memoria, red, almacenamiento |
| Kubernetes / Compute Resources / Namespace (Pods) | Por namespace: qué pod come qué |
| Kubernetes / Compute Resources / Workload | Por deployment/statefulset |
| Kubernetes / Compute Resources / Pod | Detalle de UN pod |
| Kubernetes / Networking / Cluster | Tráfico entre pods |
| Node Exporter / Nodes | Métricas a nivel SO de cada nodo (load, memory, disk) |
| Kubernetes / API server | Métricas del control plane |
| Kubernetes / Kubelet | Por nodo: pods, containers, errores |

---

## Crear un dashboard nuevo

1. Menú izquierdo → **Dashboards → New → New dashboard**
2. **Add visualization** → elige Datasource (Prometheus o Loki)
3. Pega una query PromQL (ej: `rate(http_requests_total[5m])`)
4. **Apply** → ajusta título, tipo (graph, gauge, stat) y unidades en panel derecho
5. **Save dashboard** (icono disco arriba derecha)

### Importar un dashboard existente

Grafana Labs tiene biblioteca pública con dashboards prefabricados:

1. Ve a https://grafana.com/grafana/dashboards/
2. Encuentra uno (ej: "Loki Dashboard quick search" → ID 13639)
3. En tu Grafana: **Dashboards → New → Import** → pega el ID
4. Selecciona datasource al final → **Import**

### Persistencia

Los dashboards que creas se guardan en el PVC de Grafana (`local-path`, 2 GB). Si recreas el pod, sobreviven. **Pero** si borras el PVC, se pierden. Para hacerlos a prueba de balas, guárdalos como JSON en el repo.

---

## PromQL básico

Todo en **Explore** (icono brújula a la izquierda) → datasource Prometheus.

```promql
# RPS de cualquier app HTTP
rate(http_requests_total[5m])

# Top 5 pods por CPU
topk(5, sum(rate(container_cpu_usage_seconds_total[5m])) by (pod))

# Memoria total usada por un namespace
sum(container_memory_working_set_bytes{namespace="argocd"})

# Pods Running por namespace
count(kube_pod_status_phase{phase="Running"}) by (namespace)

# % de uso de disco por nodo
100 - (node_filesystem_avail_bytes{mountpoint="/"}
        / node_filesystem_size_bytes{mountpoint="/"} * 100)

# Pods en CrashLoopBackOff
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1

# Restarts por pod en la última hora
increase(kube_pod_container_status_restarts_total[1h])

# Predicción: cuánto durará el disco al ritmo actual (4h)
predict_linear(node_filesystem_free_bytes[1h], 4*3600) < 0
```

Cheatsheet de operadores: <https://prometheus.io/docs/prometheus/latest/querying/operators/>

---

## LogQL

En Explore → datasource Loki:

```logql
# Todos los logs del namespace argocd
{namespace="argocd"}

# Solo errores
{namespace="argocd"} |= "error"

# Excluir health checks
{namespace="argocd"} |= "error" != "healthcheck"

# Logs de un pod parseados como JSON con filtro por nivel
{pod="api-7f8b7b48fb-pbv8f"} | json | level="error"

# Tasa de errores por minuto
sum(rate({namespace="argocd"} |= "error" [1m])) by (pod)

# Logs de los últimos 5 minutos con regex
{namespace=~"argo.*"} |~ "fail|error|panic"
```

> **Performance**: si tienes muchos logs, filtra primero por labels (`{namespace=...}`) y después por contenido (`|=`). Loki es rápido en labels, lento en contenido.

---

## Activar Alertmanager

Los `kube-prometheus-stack-values.yaml` lo dejan deshabilitado. Para activarlo:

```yaml
# kube-prometheus-stack-values.yaml
alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests: { cpu: 50m, memory: 100Mi }
      limits: { memory: 200Mi }
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          resources: { requests: { storage: 1Gi } }
  config:
    global:
      resolve_timeout: 5m
    route:
      receiver: 'telegram'
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
    receivers:
      - name: 'telegram'
        telegram_configs:
          - bot_token: 'TU_TOKEN_DE_TELEGRAM_BOT'
            chat_id: 123456789
            parse_mode: 'HTML'
```

Y aplica:

```bash
helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kube-prometheus-stack-values.yaml
```

---

## Cambiar retención

En `kube-prometheus-stack-values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    retention: 30d              # antes 7d
    retentionSize: 20GB         # ojo de que el PVC sea suficiente
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 25Gi     # antes 10Gi
```

```bash
helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kube-prometheus-stack-values.yaml
```

> Para Loki, edita `loki-stack-values.yaml`:
> ```yaml
> loki:
>   config:
>     table_manager:
>       retention_period: 720h    # 30 días (antes 168h)
> ```

---

## Upgrade del chart

Para subir kube-prometheus-stack a una versión más nueva:

```bash
helm repo update
helm search repo prometheus-community/kube-prometheus-stack -l | head
# Mira qué versiones hay

helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kube-prometheus-stack-values.yaml \
  --version 70.0.0   # nueva versión
```

> **Antes de upgradear**: lee siempre el CHANGELOG, especialmente cambios de major. Hay versiones que renombran fields del values y rompen.

### Rollback si algo va mal

```bash
helm history kps -n monitoring
helm rollback kps 1 -n monitoring   # vuelve a la revisión 1
```

---

## Acceder a Prometheus directo

Para queries que Grafana no permite o debug profundo:

```bash
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
```

Luego `http://localhost:9090`. UI nativa de Prometheus con sus pestañas Graph, Alerts, Targets, Status.

**Útil para**:
- Ver qué targets se están scrapeando (Status → Targets)
- Probar PromQL antes de meterlas en dashboards
- Ver reglas de alerta (Alerts)

---

## Troubleshooting

### Pods en `Pending` con error de scheduling

Probablemente no quedan recursos en los nodos. Mira:

```bash
kubectl top nodes
kubectl describe pod -n monitoring <pod>
```

Solución: bajar `requests` en values y `helm upgrade`.

### Grafana muestra "No data"

Comprueba que el datasource está accesible:

1. Grafana → Configuration → Data sources → Prometheus → **Save & test**
2. Si falla, mira los pods: `kubectl -n monitoring get pods`

### Loki da error "tenant not found"

Edita el datasource Loki en Grafana y, en **HTTP Headers**, añade:
- Key: `X-Scope-OrgID`
- Value: `fake`

### Promtail no recoge logs

```bash
kubectl -n monitoring logs daemonset/loki-stack-promtail | tail -50
kubectl -n monitoring describe daemonset/loki-stack-promtail
```

Comprueba que tiene permiso de leer `/var/log/pods/*` (k3s lo da por defecto, pero…).

### El cluster se ralentiza tras instalar el stack

Reduce recursos en values. Especialmente Prometheus (sube y sube por defecto). Prueba con:

```yaml
prometheus:
  prometheusSpec:
    retention: 3d
    resources:
      requests: { memory: 200Mi }
      limits:   { memory: 400Mi }
```

Y `helm upgrade`.

### El chart no instala — "namespace argocd already exists" o similar

Si tienes ArgoCD vigilando ya un Application, deja que él haga el upgrade en lugar de lanzar `helm upgrade` directo. Ambos chocan.

---

## Cómo migrarlo a GitOps (futuro)

Hoy está instalado vía `helm install`. Para que ArgoCD lo gestione:

```yaml
# manifests/argocd-apps/monitoring.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: 65.5.0
    helm:
      valueFiles:
        - $values/manifests/apps/monitoring/kube-prometheus-stack-values.yaml
  sources:
    - repoURL: https://github.com/Juanluiso/homelab.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated: { prune: false, selfHeal: true }
    syncOptions:
      - ServerSideApply=true
      - CreateNamespace=true
```

**Antes** de aplicar este Application: hacer `helm uninstall kps` para evitar duplicidad. ArgoCD se encargará de la instalación.
