#!/usr/bin/env bash
set -euo pipefail

pacman-key --init
pacman-key --populate archlinux

# Autoinstall service (only activates with xauto=1 + cidata).
systemctl enable x-autoinstall.service >/dev/null 2>&1 || true

# Network in the live environment (DHCP) for the installer and rescue.
systemctl enable NetworkManager.service >/dev/null 2>&1 || true