# TODO — siguientes iteraciones

- [x] **Ansibleizar instalación de k3s**: rol `ansible/roles/{common,k3s_server,k3s_agent}` con idempotencia. Wrapper `run.sh` para correr vía Docker desde cualquier OS.
- [ ] **Cloudflare Tunnel**: instalar `cloudflared` como Deployment en el cluster y exponer ArgoCD UI / Apps en `*.juanluismaldonado.dev`.
- [ ] **App-of-apps pattern**: una sola Application root que vigila `manifests/argocd-apps/` y crea el resto.
- [ ] **Stack de observabilidad**: kube-prometheus-stack vía Helm + Loki + Grafana dashboards.
- [ ] **Ingress + cert-manager**: nginx-ingress + Let's Encrypt para HTTPS automático.
- [ ] **Backup de etcd y volúmenes**: Velero o k3s built-in.
- [ ] **External Secrets Operator**: integrar con Vault del homelab.
- [ ] **Renovate / Dependabot** en el repo para mantener imágenes y charts al día.
