# TODO — siguientes iteraciones

- [x] **Ansibleizar instalación de k3s**: rol `ansible/roles/{common,k3s_server,k3s_agent}` con idempotencia.
- [x] **Stack de observabilidad**: kube-prometheus-stack + loki-stack vía Helm. Values ajustados a homelab pequeño. Master subido a 4 GB RAM.
- [x] **Migrar el stack de monitoring a ArgoCD**: Applications multi-source en `manifests/argocd-apps/`. Cambios en values → ArgoCD hace `helm upgrade` automático.
- [x] **Homepage dashboard**: dashboard del homelab con widgets en vivo (Proxmox, ArgoCD, Grafana, Prometheus, Kubernetes). Vía ArgoCD con secret externo para credenciales.
- [ ] **App-of-apps pattern**: una sola Application root que vigila `manifests/argocd-apps/` y crea el resto. Bootstrap más limpio.
- [ ] **Ingress + cert-manager**: nginx-ingress + Let's Encrypt para HTTPS automático.
- [ ] **Cloudflare Tunnel**: exponer Homepage / ArgoCD / Grafana en Internet sin abrir puertos.
- [ ] **Backup de etcd y volúmenes**: Velero o k3s built-in.
- [ ] **External Secrets Operator**: integrar con Vault del homelab.
- [ ] **Alertmanager + integración Telegram/Discord**: deshabilitado de inicio, activar cuando haya carga real.
- [ ] **Renovate / Dependabot** en el repo para mantener imágenes y charts al día.
