#!/usr/bin/env bash
# =====================================================================
# Wrapper para correr Ansible vía Docker desde cualquier OS.
# Resuelve los problemas típicos en Windows (Git Bash):
#   - MSYS_NO_PATHCONV: evita que Git Bash convierta /work a C:/...
#   - Copiar la SSH key dentro del contenedor con permisos 600
#   - Pasar inventory explícitamente (ansible.cfg ignorado en world-writable)
#
# Uso:
#   ./run.sh                          # ejecuta site.yml
#   ./run.sh -m ping                  # ad-hoc ping
#   ./run.sh -m setup --limit master  # cualquier comando de Ansible
# =====================================================================

set -euo pipefail
cd "$(dirname "$0")"

# Detectar OS para path del SSH key
case "${OSTYPE:-}" in
  msys*|cygwin*|win32*)
    SSH_DIR="/c/Users/${USER:-$USERNAME}/.ssh"
    ;;
  *)
    SSH_DIR="$HOME/.ssh"
    ;;
esac

ANSIBLE_DIR="$(pwd -W 2>/dev/null || pwd)"

# Si no se pasa nada, ejecutar el playbook completo
ARGS=("$@")
if [[ ${#ARGS[@]} -eq 0 ]]; then
  CMD="ansible-playbook -i inventory.yml site.yml"
else
  CMD="ansible -i inventory.yml ${ARGS[*]}"
fi

MSYS_NO_PATHCONV=1 docker run --rm \
  -v "${SSH_DIR}:/ssh-host:ro" \
  -v "${ANSIBLE_DIR}:/work" \
  -w /work \
  -e ANSIBLE_HOST_KEY_CHECKING=False \
  cytopia/ansible:latest-tools \
  sh -c "mkdir -p /root/.ssh \
    && cp /ssh-host/id_ed25519 /root/.ssh/ \
    && chmod 600 /root/.ssh/id_ed25519 \
    && ${CMD}"
