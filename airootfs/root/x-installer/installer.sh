#!/usr/bin/env bash
set -euo pipefail

# x installer entry point in the live environment. Runs the configurator and, if
# confirmed, the installer. With X_DRY=1 it only shows the plan.
#   X_SKIP_INSTALLER=1  skips the installer (useful in dev/tests)

if [[ "${X_SKIP_INSTALLER:-0}" == "1" ]]; then
    echo "x-install: skipped"
    exit 0
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${X_DRY:-0}" == "1" ]]; then
    JSON="${X_INSTALL_JSON:-/tmp/x-install.json}"
    [[ -f "$JSON" ]] || printf '{"disk":"/dev/sda","hostname":"x","username":"x","password":""}\n' > "$JSON"
    bash "$DIR/install.sh"
    exit 0
fi

echo "== X Installer =="
bash "$DIR/configurator.sh" || exit 1
bash "$DIR/install.sh"
