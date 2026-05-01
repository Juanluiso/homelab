# TODO — siguientes iteraciones

- [ ] **Ansibleizar instalación de k3s**: pasar el bash del README al rol Ansible `ansible/roles/k3s/`. Los manifiestos en `ansible/site.yml` deberían aplicar la misma config que el script bash actual. Esto añade reproducibilidad e idempotencia real.
- [ ] **Cloudflare Tunnel**: instalar `cloudflared` como Deployment en el cluster y exponer ArgoCD UI / Apps en `*.juanluismaldonado.dev`.
- [ ] **App-of-apps pattern**: una sola Application root que vigila `manifests/argocd-apps/` y crea el resto.
- [ ] **Stack de observabilidad**: kube-prometheus-stack vía Helm + Loki + Grafana dashboards.
- [ ] **Ingress + cert-manager**: nginx-ingress + Let's Encrypt para HTTPS automático.
- [ ] **Backup de etcd y volúmenes**: Velero o k3s built-in.
- [ ] **External Secrets Operator**: integrar con Vault del homelab.
- [ ] **Renovate / Dependabot** en el repo para mantener imágenes y charts al día.
