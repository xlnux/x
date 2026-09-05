#!/usr/bin/env bash
set -euo pipefail

# Configurador en texto del instalador x. Recolecta la configuracion minima y
# escribe /tmp/x-install.json para install.sh.
#   X_CONFIG_OUT  ruta de salida (default /tmp/x-install.json)

source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

OUT="${X_CONFIG_OUT:-/tmp/x-install.json}"
DRY="${X_DRY:-0}"

valid_hostname() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; }
valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }

# Dispositivos de bloque de tipo disk.
mapfile -t DISKS < <(lsblk -dno NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk" {print "/dev/"$1" ("$2")"}')

DISK=""
while [[ -z "$DISK" ]]; do
    if (( ${#DISKS[@]} == 0 )); then
        echo "configurador: no se encontraron discos" >&2
        exit 1
    fi
    select_one DISK "Selecciona el disco de instalacion" "${DISKS[@]}"
    DISK="${DISK%% *}"
done

HOST=""
while [[ -z "$HOST" ]]; do
    ask_value HOST "Hostname (default: x)"
    HOST="${HOST:-x}"
    valid_hostname "$HOST" || { echo "hostname invalido"; HOST=""; }
done

USER=""
while [[ -z "$USER" ]]; do
    ask_value USER "Usuario"
    valid_user "$USER" || { echo "usuario invalido"; USER=""; }
done

PASS=""
PASS2="x"
while [[ -z "$PASS" || "$PASS" != "$PASS2" ]]; do
    ask_password PASS "Contrasena del usuario"
    ask_password PASS2 "Repite la contrasena"
    [[ -n "$PASS" && "$PASS" == "$PASS2" ]] || echo "no coinciden o esta vacia"
done

if [[ "$DRY" == "1" ]]; then
    printf '{"disk":"%s","hostname":"%s","username":"%s"}\n' "$DISK" "$HOST" "$USER"
    exit 0
fi

if confirm_yes "ATENCION: se borrara todo el contenido de $DISK. Continuar?"; then
    :
else
    echo "configurador: cancelado, se abandona a una shell"
    exit 1
fi

cat > "$OUT" <<EOF
{"disk":"$DISK","hostname":"$HOST","username":"$USER","password":"$PASS"}
EOF
echo "configuracion escrita en $OUT"
