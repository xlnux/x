#!/usr/bin/env bash
set -euo pipefail

# Entry del instalador x en el live. Ejecuta el configurador y, si se
# confirma, el instalador. Con X_DRY=1 solo muestra el plan.
#   X_SKIP_INSTALLER=1  salta el instalador (util en dev/tests)

if [[ "${X_SKIP_INSTALLER:-0}" == "1" ]]; then
    echo "x-install: omitido"
    exit 0
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${X_DRY:-0}" == "1" ]]; then
    JSON="${X_INSTALL_JSON:-/tmp/x-install.json}"
    [[ -f "$JSON" ]] || printf '{"disk":"/dev/sda","hostname":"x","username":"x","password":""}\n' > "$JSON"
    bash "$DIR/install.sh"
    exit 0
fi

echo "== Instalador x =="
bash "$DIR/configurator.sh" || exit 1
bash "$DIR/install.sh"
