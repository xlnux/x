#!/usr/bin/env bash
set -euo pipefail

# Instalador x: particiona, pacstrap, configura y provisiona en chroot.
# Lee la configuracion JSON del configurador.
#   X_INSTALL_JSON  ruta (default /tmp/x-install.json)
#   X_DRY=1         solo validar y mostrar el plan (tests)

source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

JSON="${X_INSTALL_JSON:-/tmp/x-install.json}"
DRY="${X_DRY:-0}"

jget() {
    sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" "$JSON"
}

[[ -f "$JSON" ]] || { echo "instalador: no existe $JSON (ejecuta el configurador)" >&2; exit 1; }

DISK="$(jget disk)"
HOST="$(jget hostname)"
USER="$(jget username)"
PASS="$(jget password)"

[[ -n "$DISK" && -n "$HOST" && -n "$USER" ]] || { echo "instalador: JSON incompleto" >&2; exit 1; }

if [[ "$DRY" == "1" ]]; then
    echo "plan de instalacion:"
    echo "  disco:    $DISK (se borra)"
    echo "  hostname: $HOST"
    echo "  usuario:  $USER"
    exit 0
fi

[[ "$(id -u)" -eq 0 ]] || { echo "instalador: requiere root" >&2; exit 1; }
[[ -b "$DISK" ]] || { echo "instalador: $DISK no es un dispositivo de bloque" >&2; exit 1; }

partdev() {
    local d="$1"
    if [[ "$d" =~ [0-9]$ ]]; then
        printf '%sp' "$d"
    else
        printf '%s' "$d"
    fi
}

EFI="$(partdev "$DISK")1"
ROOTP="$(partdev "$DISK")2"
MNT=/mnt
PKGLIST="${X_PKGLIST:-/run/archiso/packages.x86_64}"

echo "== particionando $DISK"
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -n 2:0:0 -t 2:8300 "$DISK"
partprobe "$DISK" || true
sleep 1

echo "== formateando"
mkfs.vfat -F32 "$EFI"
mkfs.btrfs -f "$ROOTP"

echo "== montando"
mount "$ROOTP" "$MNT"
mkdir -p "$MNT/boot"
mount "$EFI" "$MNT/boot"

PKGS="base base-devel linux linux-firmware grub efibootmgr sudo git jq gum networkmanager"
if [[ -f "$PKGLIST" ]]; then
    PKGS="$PKGS $(sed 's/#.*//' "$PKGLIST" | tr '\n' ' ')"
fi

# Espera a que haya red antes del pacstrap (dhcp del live).
echo "== esperando red"
for i in $(seq 1 60); do
    if getent ahostsv4 geo.mirror.pkgbuild.com >/dev/null 2>&1; then
        echo "red disponible"
        break
    fi
    if [[ "$i" -eq 60 ]]; then
        echo "aviso: sin red tras 120s; pacstrap fallara" >&2
    fi
    sleep 2
done

echo "== pacstrap (online; repos oficiales + [x])"
pacstrap -K "$MNT" $PKGS

echo "== instalando x-scripts (payload del live, offline)"
XS_PKG="$(ls /root/x-installer/packages/x-scripts-*.pkg.tar.zst 2>/dev/null | head -1 || true)"
if [[ -n "$XS_PKG" ]]; then
    cp -f "$XS_PKG" "$MNT/root/"
    arch-chroot "$MNT" pacman -U --noconfirm "/root/$(basename "$XS_PKG")" >/dev/null
    rm -f "$MNT/root/$(basename "$XS_PKG")"
else
    echo "aviso: no se encontro x-scripts en el live" >&2
fi

echo "== configuración base"
genfstab -U "$MNT" >> "$MNT/etc/fstab"

arch-chroot "$MNT" bash -c 'ln -sf /usr/share/zoneinfo/UTC /etc/localtime'
arch-chroot "$MNT" bash -c 'sed -i "s/^#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen && locale-gen >/dev/null'
printf 'LANG=en_US.UTF-8\n' > "$MNT/etc/locale.conf"
printf '%s\n' "$HOST" > "$MNT/etc/hostname"

echo "== usuario"
arch-chroot "$MNT" useradd -m -G wheel -s /bin/bash "$USER"
printf '%s:%s\n' "$USER" "$PASS" | arch-chroot "$MNT" chpasswd
arch-chroot "$MNT" sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "== aprovisionamiento (x-scripts)"
arch-chroot "$MNT" env X_HW_AUTO=0 x setup
arch-chroot "$MNT" runuser -u "$USER" -- env X_HYPRLAND=0 X_HW_AUTO=0 /usr/bin/x setup --user

echo "== bootloader"
arch-chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=x --no-nvram --recheck
arch-chroot "$MNT" grub-install --target=i386-pc --boot-directory=/boot "$DISK"
arch-chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg
if [[ -x "$MNT/usr/bin/x-release-apply" ]]; then
    arch-chroot "$MNT" /usr/bin/x-release-apply || true
fi

umount -R "$MNT"
echo
echo "instalacion completada. Reinicia y retira el medio."
