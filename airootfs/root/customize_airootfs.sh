#!/usr/bin/env bash
set -euo pipefail

pacman-key --init
pacman-key --populate archlinux

# Servicio de autoinstalacion (se activa solo con xauto=1 + cidata).
systemctl enable x-autoinstall.service >/dev/null 2>&1 || true