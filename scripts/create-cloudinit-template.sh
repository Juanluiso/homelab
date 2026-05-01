#!/usr/bin/env bash
# =====================================================================
# Crea un template Ubuntu 22.04 con cloud-init en Proxmox.
# Se ejecuta UNA VEZ en el host Proxmox como root.
# Después, Terraform clona desde este template para cada VM.
#
# Uso (desde tu PC):
#   ssh root@192.168.1.10 'bash -s' < scripts/create-cloudinit-template.sh
# =====================================================================

set -euo pipefail

# ---------- Parámetros editables ----------
TEMPLATE_VMID=9000
TEMPLATE_NAME="ubuntu-2204-cloudinit"
STORAGE_POOL="local-lvm"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_FILE="/var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img"
NETWORK_BRIDGE="vmbr0"

# ---------- Comprobaciones ----------
if [[ $EUID -ne 0 ]]; then
  echo "Este script debe ejecutarse como root en el host Proxmox" >&2
  exit 1
fi

if qm status "$TEMPLATE_VMID" &>/dev/null; then
  echo "El VMID $TEMPLATE_VMID ya existe. Si quieres recrear el template, primero:"
  echo "  qm destroy $TEMPLATE_VMID"
  exit 1
fi

# ---------- Descargar cloud image ----------
if [[ ! -f "$IMAGE_FILE" ]]; then
  echo "==> Descargando Ubuntu 22.04 cloud image..."
  wget -O "$IMAGE_FILE" "$IMAGE_URL"
else
  echo "==> Cloud image ya descargada ($IMAGE_FILE)"
fi

# Instalar tools que necesitamos para inyectar el agente de Proxmox y QEMU guest agent
echo "==> Instalando paquetes en la imagen (qemu-guest-agent)..."
apt-get install -y libguestfs-tools >/dev/null 2>&1 || true
virt-customize -a "$IMAGE_FILE" --install qemu-guest-agent
virt-customize -a "$IMAGE_FILE" --run-command 'systemctl enable qemu-guest-agent'

# ---------- Crear la VM ----------
echo "==> Creando VM $TEMPLATE_VMID..."
qm create "$TEMPLATE_VMID" \
  --name "$TEMPLATE_NAME" \
  --memory 2048 \
  --cores 2 \
  --cpu host \
  --net0 "virtio,bridge=$NETWORK_BRIDGE" \
  --agent enabled=1 \
  --serial0 socket \
  --vga serial0 \
  --ostype l26

echo "==> Importando disco a $STORAGE_POOL..."
qm importdisk "$TEMPLATE_VMID" "$IMAGE_FILE" "$STORAGE_POOL"

echo "==> Configurando disco y boot..."
qm set "$TEMPLATE_VMID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE_POOL}:vm-${TEMPLATE_VMID}-disk-0"
qm set "$TEMPLATE_VMID" --boot c --bootdisk scsi0
qm set "$TEMPLATE_VMID" --ide2 "${STORAGE_POOL}:cloudinit"

echo "==> Convirtiendo a template..."
qm template "$TEMPLATE_VMID"

echo
echo "✅ Template '$TEMPLATE_NAME' (VMID $TEMPLATE_VMID) creado correctamente."
echo "Ahora puedes lanzar 'tofu apply' desde tu PC."
