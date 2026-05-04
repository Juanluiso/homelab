# TODO — siguientes iteraciones

- [x] **Ansibleizar instalación de k3s**: rol `ansible/roles/{common,k3s_server,k3s_agent}` con idempotencia.
- [x] **Stack de observabilidad**: kube-prometheus-stack + loki-stack vía Helm. Values ajustados a homelab pequeño. Master subido a 4 GB RAM.
- [ ] **Migrar el stack de monitoring a ArgoCD**: Application con `source.helm` apuntando a los charts. Ahora está instalado vía `helm install` directo.
- [ ] **Cloudflare Tunnel**: instalar `cloudflared` como Deployment en el cluster y exponer ArgoCD UI / Grafana en `*.juanluismaldonado.dev`.
- [ ] **App-of-apps pattern**: una sola Application root que vigila `manifests/argocd-apps/` y crea el resto.
- [ ] **Ingress + cert-manager**: nginx-ingress + Let's Encrypt para HTTPS automático.
- [ ] **Backup de etcd y volúmenes**: Velero o k3s built-in.
- [ ] **External Secrets Operator**: integrar con Vault del homelab.
- [ ] **Alertmanager + integración Telegram/Discord**: deshabilitado de inicio, activar cuando haya carga real.
- [ ] **Renovate / Dependabot** en el repo para mantener imágenes y charts al día.
