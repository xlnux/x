#!/usr/bin/env bash
set -euo pipefail

# X installer: partitions, pacstrap, configures, provisions, installs the
# bootloader in chroot.
#   X_INSTALL_JSON  config path (default /tmp/x-install.json)
#   X_DRY=1         validate and print the plan only (tests)

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
LANG_CODE="$(jget language)";         LANG_CODE="${LANG_CODE:-en}"
LOCALE="$(jget locale)";              LOCALE="${LOCALE:-en_US.UTF-8}"
KEYMAP="$(jget keyboard)";            KEYMAP="${KEYMAP:-us}"
TIMEZONE="$(jget timezone)";          TIMEZONE="${TIMEZONE:-UTC}"
PROFILE="$(jget profile)";            PROFILE="${PROFILE:-full}"
BOOT="$(jget bootloader)";            BOOT="${BOOT:-grub}"
ENC="$(jget encryption)";             ENC="${ENC:-no}"
LUKS_PASS="$(jget luks_password)"
HYPR="$(jget hyprland)";              HYPR="${HYPR:-no}"

[[ -n "$DISK" && -n "$HOST" && -n "$USER" ]] || { echo "installer: incomplete JSON" >&2; exit 1; }

if [[ "$DRY" == "1" ]]; then
    echo "install plan:"
    echo "  disk:      $DISK (will be erased)"
    echo "  hostname:  $HOST"
    echo "  user:      $USER"
    echo "  language:  $LANG_CODE ($LOCALE)  keyboard: $KEYMAP  timezone: $TIMEZONE"
    echo "  profile:   $PROFILE"
    echo "  bootloader:$BOOT"
    echo "  encryption:$ENC   hyprland:$HYPR"
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

MNT=/mnt
PKGLIST="${X_PKGLIST:-/run/archiso/packages.x86_64}"

echo "== partitioning $DISK"
sgdisk --zap-all "$DISK"
if [[ "$BOOT" == "grub" ]]; then
    sgdisk -n 1:0:+1M -t 1:ef02 -n 2:0:+512M -t 2:ef00 -n 3:0:0 -t 3:8300 "$DISK"
    EFI="$(partdev "$DISK")2"
    ROOTP="$(partdev "$DISK")3"
else
    sgdisk -n 1:0:+512M -t 1:ef00 -n 2:0:0 -t 2:8300 "$DISK"
    EFI="$(partdev "$DISK")1"
    ROOTP="$(partdev "$DISK")2"
fi
partprobe "$DISK" || true
sleep 1

ROOT_DEV="$ROOTP"
LUKS_UUID=""
if [[ "$ENC" == "yes" ]]; then
    [[ -n "$LUKS_PASS" ]] || LUKS_PASS="$PASS"
    echo "== luks2 on $ROOTP"
    printf '%s' "$LUKS_PASS" | cryptsetup luksFormat --type luks2 --batch-mode "$ROOTP"
    printf '%s' "$LUKS_PASS" | cryptsetup open "$ROOTP" xroot
    ROOT_DEV=/dev/mapper/xroot
    LUKS_UUID="$(blkid -s UUID -o value "$ROOTP")"
fi

echo "== formatting"
mkfs.vfat -F32 "$EFI"
mkfs.btrfs -f "$ROOT_DEV"

echo "== mounting"
mount "$ROOT_DEV" "$MNT"
mkdir -p "$MNT/boot"
mount "$EFI" "$MNT/boot"

# Package set per profile.
EXTRA="base base-devel linux linux-firmware sudo networkmanager openssh git jq x-release"
[[ "$BOOT" == "grub" ]] && EXTRA="$EXTRA grub efibootmgr"
[[ "$ENC" == "yes" ]] && EXTRA="$EXTRA cryptsetup"
if [[ "$PROFILE" == "core" ]]; then
    PKGS="$EXTRA vim zsh"
else
    PKGS="$EXTRA"
    if [[ -f "$PKGLIST" ]]; then
        PKGS="$PKGS $(sed 's/#.*//' "$PKGLIST" | tr '\n' ' ')"
    fi
fi

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

echo "== installing x-scripts (offline payload from the live)"
XS_PKG="$(ls /root/x-installer/packages/x-scripts-*.pkg.tar.zst 2>/dev/null | head -1 || true)"
if [[ -n "$XS_PKG" ]]; then
    cp -f "$XS_PKG" "$MNT/root/"
    arch-chroot "$MNT" pacman -U --noconfirm "/root/$(basename "$XS_PKG")" >/dev/null
    rm -f "$MNT/root/$(basename "$XS_PKG")"
else
    echo "warning: x-scripts package not found in the live" >&2
fi

echo "== base configuration"
genfstab -U "$MNT" >> "$MNT/etc/fstab"

arch-chroot "$MNT" ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
arch-chroot "$MNT" bash -c "sed -i 's/^#$LOCALE/$LOCALE/' /etc/locale.gen && locale-gen >/dev/null"
printf 'LANG=%s\n' "$LOCALE" > "$MNT/etc/locale.conf"
printf 'KEYMAP=%s\n' "$KEYMAP" > "$MNT/etc/vconsole.conf"
printf '%s\n' "$HOST" > "$MNT/etc/hostname"

echo "== user"
arch-chroot "$MNT" useradd -m -G wheel -s /bin/bash "$USER"
printf '%s:%s\n' "$USER" "$PASS" | arch-chroot "$MNT" chpasswd
arch-chroot "$MNT" sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "== provisioning (x-scripts)"
arch-chroot "$MNT" env X_HW_AUTO=0 x setup
arch-chroot "$MNT" runuser -u "$USER" -- env X_HYPRLAND=0 X_HW_AUTO=0 /usr/bin/x setup --user

if [[ "$HYPR" == "yes" ]]; then
    echo "== installing Hyprland setup (external, network)"
    set +e
    arch-chroot "$MNT" runuser -u "$USER" -- env X_HYPRLAND=1 X_HW_AUTO=0 /usr/bin/x setup --user
    echo "warning: hyprland setup exited with $?"
    set -e
fi

if [[ "$ENC" == "yes" ]]; then
    echo "== initramfs (LUKS)"
    arch-chroot "$MNT" bash -c 'sed -i "s/^HOOKS=.*/HOOKS=(base udev autodetect modconf keyboard keymap consolefont block encrypt filesystems)/" /etc/mkinitcpio.conf'
    arch-chroot "$MNT" mkinitcpio -P >/dev/null
fi

CMDROOT="root=UUID=$(blkid -s UUID -o value "$ROOT_DEV") rw"
[[ "$ENC" == "yes" ]] && CMDROOT="cryptdevice=UUID=$LUKS_UUID:xroot root=/dev/mapper/xroot rw"

echo "== bootloader ($BOOT)"
if [[ "$BOOT" == "systemd-boot" ]]; then
    arch-chroot "$MNT" bootctl --esp-path=/boot --no-variables install >/dev/null
    mkdir -p "$MNT/boot/loader/entries"
    cat > "$MNT/boot/loader/loader.conf" <<'EOF'
default x.conf
timeout 5
console-mode max
EOF
    cat > "$MNT/boot/loader/entries/x.conf" <<EOF
title   X Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $CMDROOT
EOF
else
    if [[ "$ENC" == "yes" ]]; then
        arch-chroot "$MNT" bash -c "sed -i 's|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$CMDROOT\"|' /etc/default/grub"
    fi
    arch-chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
    arch-chroot "$MNT" grub-install --target=i386-pc --boot-directory=/boot "$DISK"
    arch-chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg
fi

if [[ -x "$MNT/usr/bin/x-release-apply" ]]; then
    arch-chroot "$MNT" /usr/bin/x-release-apply || true
fi

umount -R "$MNT"
echo
echo "installation complete. Reboot and remove the installation medium."
