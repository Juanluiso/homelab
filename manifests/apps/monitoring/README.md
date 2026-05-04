# Stack de observabilidad — Prometheus + Grafana + Loki

Métricas (Prometheus), visualización (Grafana) y agregación de logs (Loki + Promtail) sobre el cluster k3s.

## Componentes desplegados

| Componente | Versión chart | Función |
|---|---|---|
| kube-prometheus-stack | 65.5.0 | Prometheus + Grafana + node-exporter + kube-state-metrics |
| loki-stack | 2.10.2 | Loki (logs) + Promtail (DaemonSet) |

## Instalación

Ambas se instalan vía Helm:

```bash
export KUBECONFIG=~/.kube/homelab-config

# Repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Namespace
kubectl create namespace monitoring

# Stack Prometheus + Grafana
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kube-prometheus-stack-values.yaml \
  --version 65.5.0

# Stack Loki
helm install loki-stack grafana/loki-stack \
  -n monitoring \
  -f loki-stack-values.yaml \
  --version 2.10.2
```

## Acceso a Grafana

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

Abrir `http://localhost:3000`:
- **Usuario:** `admin`
- **Password:** `homelab-admin` (cambiar tras primer login)

## Recursos consumidos

Con los `values.yaml` ajustados, el stack pesa ~1.5 GB de RAM en el cluster:

- Prometheus: ~500 MB (retention 7 días)
- Grafana: ~150 MB
- Operator: ~100 MB
- node-exporter (3): 50 MB c/u
- kube-state-metrics: ~80 MB
- Loki: ~150 MB
- Promtail (3): 50 MB c/u

## Storage

Volúmenes persistentes con `local-path` (k3s built-in):
- Prometheus: 10 GB
- Grafana: 2 GB
- Loki: 5 GB

## Lo que NO hemos habilitado

- **Alertmanager** (deshabilitado para ahorrar RAM). Cuando lo necesites, edita los values y `helm upgrade`.
- **kubeControllerManager / kubeScheduler / kubeProxy / kubeEtcd** (k3s no los expone separados).

## Migrar a GitOps

Cuando quieras pasar de "Helm install manual" a "ArgoCD vigila este repo":

1. Crear `manifests/argocd-apps/monitoring.yaml` con un `Application` que use `source.helm` apuntando al chart.
2. Aplicar el Application al cluster.
3. ArgoCD se encargará de los upgrades automáticos cuando cambies `values.yaml`.

Pendiente en el TODO.md.
