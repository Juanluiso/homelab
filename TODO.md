# TODO — siguientes iteraciones

- [x] **Ansibleizar instalación de k3s**: rol `ansible/roles/{common,k3s_server,k3s_agent}` con idempotencia.
- [x] **Stack de observabilidad**: kube-prometheus-stack + loki-stack vía Helm. Values ajustados a homelab pequeño. Master subido a 4 GB RAM.
- [x] **Migrar el stack de monitoring a ArgoCD**: Applications multi-source en `manifests/argocd-apps/`. Cambios en values → ArgoCD hace `helm upgrade` automático.
- [x] **Homepage dashboard**: dashboard del homelab con widgets en vivo (Proxmox, ArgoCD, Grafana, Prometheus, Kubernetes). Vía ArgoCD con secret externo para credenciales.
- [x] **Uptime Kuma + status page**: monitor de servicios + página de estado. Manifests planos (PVC + Deployment + Service) gestionados por ArgoCD. Widget integrado en Homepage.
- [x] **Cloudflare Tunnel (Quick)**: cloudflared en el cluster con `--url` apuntando a Homepage. URL aleatoria en `*.trycloudflare.com`. Pendiente migrar a Named Tunnel cuando haya dominio.
- [ ] **Migrar a Named Tunnel** (requiere dominio): URL persistente y bonita, exponer varios servicios a la vez, Cloudflare Access con auth.
- [ ] **App-of-apps pattern**: una sola Application root que vigila `manifests/argocd-apps/` y crea el resto. Bootstrap más limpio.
- [ ] **Ingress + cert-manager**: nginx-ingress + Let's Encrypt para HTTPS automático.
- [ ] **Backup de etcd y volúmenes**: Velero o k3s built-in.
- [ ] **External Secrets Operator**: integrar con Vault del homelab.
- [ ] **Alertmanager + integración Telegram/Discord**: deshabilitado de inicio, activar cuando haya carga real.
- [ ] **Renovate / Dependabot** en el repo para mantener imágenes y charts al día.
