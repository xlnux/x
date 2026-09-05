#!/usr/bin/env bash
set -euo pipefail

# Text configurator for the x installer. Collects the minimal configuration and
# writes /tmp/x-install.json for install.sh.
#   X_CONFIG_OUT  output path (default /tmp/x-install.json)

source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

OUT="${X_CONFIG_OUT:-/tmp/x-install.json}"
DRY="${X_DRY:-0}"

valid_hostname() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; }
valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }

# Block devices of type disk.
mapfile -t DISKS < <(lsblk -dno NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk" {print "/dev/"$1" ("$2")"}')

DISK=""
while [[ -z "$DISK" ]]; do
    if (( ${#DISKS[@]} == 0 )); then
        echo "configurator: no disks found" >&2
        exit 1
    fi
    select_one DISK "Select the installation disk" "${DISKS[@]}"
    DISK="${DISK%% *}"
done

HOST=""
while [[ -z "$HOST" ]]; do
    ask_value HOST "Hostname (default: x)"
    HOST="${HOST:-x}"
    valid_hostname "$HOST" || { echo "invalid hostname"; HOST=""; }
done

USER=""
while [[ -z "$USER" ]]; do
    ask_value USER "User"
    valid_user "$USER" || { echo "invalid user"; USER=""; }
done

PASS=""
PASS2="x"
while [[ -z "$PASS" || "$PASS" != "$PASS2" ]]; do
    ask_password PASS "User password"
    ask_password PASS2 "Repeat the password"
    [[ -n "$PASS" && "$PASS" == "$PASS2" ]] || echo "passwords do not match or are empty"
done

if [[ "$DRY" == "1" ]]; then
    printf '{"disk":"%s","hostname":"%s","username":"%s"}\n' "$DISK" "$HOST" "$USER"
    exit 0
fi

if confirm_yes "WARNING: all content on $DISK will be erased. Continue?"; then
    :
else
    echo "configurator: cancelled, dropping to a shell"
    exit 1
fi

cat > "$OUT" <<EOF
{"disk":"$DISK","hostname":"$HOST","username":"$USER","password":"$PASS"}
EOF
echo "configuration written to $OUT"
