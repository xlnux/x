#!/usr/bin/env bash
set -euo pipefail

# X installer: partitions, pacstrap, configures, and provisions in chroot.
# Reads the JSON configuration written by the configurator.
#   X_INSTALL_JSON  path (default /tmp/x-install.json)
#   X_DRY=1         only validate and show the plan (tests)

source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

JSON="${X_INSTALL_JSON:-/tmp/x-install.json}"
DRY="${X_DRY:-0}"

jget() {
    sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" "$JSON"
}

[[ -f "$JSON" ]] || { echo "installer: $JSON does not exist (run the configurator)" >&2; exit 1; }

DISK="$(jget disk)"
HOST="$(jget hostname)"
USER="$(jget username)"
PASS="$(jget password)"

[[ -n "$DISK" && -n "$HOST" && -n "$USER" ]] || { echo "installer: incomplete JSON" >&2; exit 1; }

if [[ "$DRY" == "1" ]]; then
    echo "installation plan:"
    echo "  disk:    $DISK (will be erased)"
    echo "  hostname: $HOST"
    echo "  user:    $USER"
    exit 0
fi

[[ "$(id -u)" -eq 0 ]] || { echo "installer: requires root" >&2; exit 1; }
[[ -b "$DISK" ]] || { echo "installer: $DISK is not a block device" >&2; exit 1; }

partdev() {
    local d="$1"
    if [[ "$d" =~ [0-9]$ ]]; then
        printf '%sp' "$d"
    else
        printf '%s' "$d"
    fi
}

BIOSP="$(partdev "$DISK")1"
EFI="$(partdev "$DISK")2"
ROOTP="$(partdev "$DISK")3"
MNT=/mnt
PKGLIST="${X_PKGLIST:-/run/archiso/packages.x86_64}"

echo "== partitioning $DISK"
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+1M -t 1:ef02 -n 2:0:+512M -t 2:ef00 -n 3:0:0 -t 3:8300 "$DISK"
partprobe "$DISK" || true
sleep 1

echo "== formatting"
mkfs.vfat -F32 "$EFI"
mkfs.btrfs -f "$ROOTP"

echo "== mounting"
mount "$ROOTP" "$MNT"
mkdir -p "$MNT/boot"
mount "$EFI" "$MNT/boot"

PKGS="base base-devel linux linux-firmware grub efibootmgr sudo git jq gum networkmanager"
if [[ -f "$PKGLIST" ]]; then
    PKGS="$PKGS $(sed 's/#.*//' "$PKGLIST" | tr '\n' ' ')"
fi

# Wait for network before pacstrap (live dhcp).
echo "== waiting for network"
for i in $(seq 1 60); do
    if getent ahostsv4 geo.mirror.pkgbuild.com >/dev/null 2>&1; then
        echo "network available"
        break
    fi
    if [[ "$i" -eq 60 ]]; then
        echo "warning: no network after 120s; pacstrap will fail" >&2
    fi
    sleep 2
done

echo "== pacstrap (online; official repos + [x])"
pacstrap -K "$MNT" $PKGS

echo "== installing x-scripts (offline live payload)"
XS_PKG="$(ls /root/x-installer/packages/x-scripts-*.pkg.tar.zst 2>/dev/null | head -1 || true)"
if [[ -n "$XS_PKG" ]]; then
    cp -f "$XS_PKG" "$MNT/root/"
    arch-chroot "$MNT" pacman -U --noconfirm "/root/$(basename "$XS_PKG")" >/dev/null
    rm -f "$MNT/root/$(basename "$XS_PKG")"
else
    echo "warning: x-scripts not found in the live environment" >&2
fi

echo "== base configuration"
genfstab -U "$MNT" >> "$MNT/etc/fstab"

arch-chroot "$MNT" bash -c 'ln -sf /usr/share/zoneinfo/UTC /etc/localtime'
arch-chroot "$MNT" bash -c 'sed -i "s/^#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen && locale-gen >/dev/null'
printf 'LANG=en_US.UTF-8\n' > "$MNT/etc/locale.conf"
printf '%s\n' "$HOST" > "$MNT/etc/hostname"

echo "== user"
arch-chroot "$MNT" useradd -m -G wheel -s /bin/bash "$USER"
printf '%s:%s\n' "$USER" "$PASS" | arch-chroot "$MNT" chpasswd
arch-chroot "$MNT" sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "== provisioning (x-scripts)"
arch-chroot "$MNT" env X_HW_AUTO=0 x setup
arch-chroot "$MNT" runuser -u "$USER" -- env X_HYPRLAND=0 X_HW_AUTO=0 /usr/bin/x setup --user

echo "== bootloader"
arch-chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
arch-chroot "$MNT" grub-install --target=i386-pc --boot-directory=/boot "$DISK"
arch-chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg
if [[ -x "$MNT/usr/bin/x-release-apply" ]]; then
    arch-chroot "$MNT" /usr/bin/x-release-apply || true
fi

umount -R "$MNT"
echo
echo "installation complete. Reboot and remove the installation media."
