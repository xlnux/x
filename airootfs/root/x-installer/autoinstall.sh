#!/usr/bin/env bash
set -euo pipefail

# Autoinstalacion desatendida. Se activa SOLO si el cmdline lleva xauto=1 y
# existe un disco con etiqueta cidata que contenga x-install.json.
#   /dev/disk/by-label/cidata  ->  x-install.json  ({"disk":"/dev/vda", ...})
# Corre como servicio systemd (x-autoinstall.service) en el live.

dbg() {
    printf 'autoinstall: %s\n' "$*" >/dev/ttyS0 2>/dev/null || printf 'autoinstall: %s\n' "$*" >/dev/console 2>/dev/null || true
}

dbg "cmdline: $(cat /proc/cmdline)"

grep -Fqa 'xauto=1' /proc/cmdline || {
    dbg "sin xauto=1; se omite"
    exit 0
}

udevadm settle || true

CIMNT=/run/cidata
mkdir -p "$CIMNT"

DEV="$(blkid -L cidata 2>/dev/null || true)"
dbg "cidata dev: ${DEV:-ninguno}"

if [[ -z "$DEV" ]]; then
    dbg "sin disco cidata; se omite"
    exit 0
fi

if ! mount -o ro "$DEV" "$CIMNT"; then
    dbg "no se pudo montar cidata en $CIMNT"
    exit 0
fi

JSON="$CIMNT/x-install.json"
if [[ ! -f "$JSON" ]]; then
    dbg "falta x-install.json en cidata; se omite"
    umount "$CIMNT"
    exit 0
fi

dbg "instalacion desatendida desde $DEV"
{ X_INSTALL_JSON="$JSON" bash -x /root/x-installer/install.sh; } 2>&1 | tee /dev/ttyS0 >/dev/null || true
rc=${PIPESTATUS[0]}
dbg "install.sh rc=$rc"
umount "$CIMNT"
exit "$rc"
