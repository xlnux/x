#!/usr/bin/env bash
set -euo pipefail

# Autoinstalacion desatendida. Se activa SOLO si el cmdline lleva xauto=1 y
# existe un disco con etiqueta cidata que contenga x-install.json.
#   /dev/disk/by-label/cidata  ->  x-install.json  ({"disk":"/dev/vda", ...})
# Corre como servicio systemd (x-autoinstall.service) en el live.

grep -Fqa 'xauto=1' /proc/cmdline || exit 0

CIMNT=/run/cidata
mkdir -p "$CIMNT"

DEV="$(blkid -L cidata 2>/dev/null || true)"
if [[ -z "$DEV" ]]; then
    echo "x-autoinstall: sin disco cidata; se omite"
    exit 0
fi

mount -o ro "$DEV" "$CIMNT" || {
    echo "x-autoinstall: no se pudo montar cidata" >&2
    exit 0
}

JSON="$CIMNT/x-install.json"
if [[ ! -f "$JSON" ]]; then
    echo "x-autoinstall: falta x-install.json en cidata; se omite"
    umount "$CIMNT"
    exit 0
fi

echo "x-autoinstall: instalacion desatendida desde $DEV"
X_INSTALL_JSON="$JSON" bash /root/x-installer/install.sh
rc=$?
umount "$CIMNT"
exit $rc
