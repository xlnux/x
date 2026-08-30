#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────
# x postinstall: Branding, Configs, DE Settings
# ────────────────────────────────────────────────

# 0) Verify /mnt
if ! mountpoint -q /mnt; then
  echo "[x] Error: /mnt is not mounted. Did archinstall finish successfully?"
  exit 1
fi

echo "[x] Starting Post-Install Configuration..."

# Helper: chroot execution
in_chroot() {
  arch-chroot /mnt sh -c "$1"
}

# 1) System Identity (/etc/os-release)
echo "[x] Configuring System Identity..."
cat > /mnt/etc/os-release <<'EOF'
NAME="X"
PRETTY_NAME="X"
ID=x
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="0;36"
HOME_URL="https://xscriptor.io/x"
DOCUMENTATION_URL="https://xscriptor.io/x/docs"
SUPPORT_URL="https://xscriptor.io/x/support"
BUG_REPORT_URL="https://github.com/xlnux/x"
LOGO=x
EOF

# 2) Asset Installation
echo "[x] Installing Assets..."
ASSET_DIR="/root/x-assets"
WALL="x-wallpaper.png"

# Icon
install -d /mnt/usr/share/icons/hicolor/scalable/apps
[ -f "$ASSET_DIR/icons/distributor-logo.svg" ] && install -m 0644 "$ASSET_DIR/icons/distributor-logo.svg" /mnt/usr/share/icons/hicolor/scalable/apps/

# Wallpaper
install -d /mnt/usr/share/backgrounds/x
[ -f "$ASSET_DIR/backgrounds/$WALL" ] && install -m 0644 "$ASSET_DIR/backgrounds/$WALL" /mnt/usr/share/backgrounds/x/

# GNOME Branding
if in_chroot "pacman -Qq gnome-shell" >/dev/null 2>&1 || [ -d /mnt/usr/share/gnome-shell ]; then
  echo "[x] Applying GNOME Branding..."
  
  # Register wallpaper so it shows up in "Background" settings
  install -d /mnt/usr/share/gnome-background-properties
  cat > /mnt/usr/share/gnome-background-properties/x-wallpapers.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>x Default</name>
    <filename>/usr/share/backgrounds/x/$WALL</filename>
    <options>zoom</options>
    <pcolor>#000000</pcolor>
    <scolor>#000000</scolor>
  </wallpaper>
</wallpapers>
EOF

  # GSchema Overrides
  install -d /mnt/usr/share/glib-2.0/schemas
  cat > /mnt/usr/share/glib-2.0/schemas/99-x-branding.gschema.override <<EOF
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/x/$WALL'
picture-uri-dark='file:///usr/share/backgrounds/x/$WALL'
picture-options='zoom'
primary-color='#000000'
secondary-color='#000000'

[org.gnome.login-screen]
logo='/usr/share/icons/hicolor/scalable/apps/distributor-logo.svg'

[org.gnome.desktop.interface]
color-scheme='prefer-dark'
EOF

  # Recompile schemas
  if in_chroot "command -v glib-compile-schemas" >/dev/null 2>&1; then
    in_chroot "glib-compile-schemas /usr/share/glib-2.0/schemas/"
  fi
fi

# KDE Plasma Branding
# Check for plasma-desktop package or plasma directory
if in_chroot "pacman -Qq plasma-desktop" >/dev/null 2>&1 || [ -d /mnt/usr/share/plasma ]; then
  echo "[x] Applying KDE Plasma Branding..."
  install -d /mnt/etc/xdg
  
  # Global wallpaper override
  cat > /mnt/etc/xdg/plasma-org.kde.plasma.desktop-appletsrc <<EOF
[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/backgrounds/x/$WALL
EOF

  # Lock screen
  cat > /mnt/etc/xdg/kscreenlockerrc <<EOF
[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/backgrounds/x/$WALL
EOF
fi

# XFCE Branding
# Check for xfce4-session package or xfce4 directory
if in_chroot "pacman -Qq xfce4-session" >/dev/null 2>&1 || [ -d /mnt/usr/share/xfce4 ]; then
  echo "[x] Applying XFCE Branding..."
  install -d /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml
  cat > /mnt/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/x/$WALL"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
fi

# 4) Display Manager Configuration

# SDDM (KDE default)
if in_chroot "command -v sddm" >/dev/null 2>&1; then
  echo "[x] Configuring SDDM..."
  install -d /mnt/etc/sddm.conf.d
  cat > /mnt/etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=breeze
EOF
  # Note: SDDM themes are complex, but setting background requires editing the theme files or using a theme that supports overrides.
  # We try to set the theme config if possible.
fi

# LightDM (XFCE default)
if in_chroot "command -v lightdm" >/dev/null 2>&1; then
  echo "[x] Configuring LightDM..."
  install -d /mnt/etc/lightdm
  cat > /mnt/etc/lightdm/lightdm-gtk-greeter.conf <<EOF
[greeter]
background=/usr/share/backgrounds/x/$WALL
icon-theme-name=Adwaita
font-name=Sans 10
EOF
fi

# GDM (GNOME default)
# GDM picks up the org.gnome.login-screen schema override we set earlier.

# 5) Fetch and Apply Remote Configurations (SKEL)
echo "[x] Fetching remote configurations (Skel)..."
SKEL_SRC="/root/x-assets/skel/.config"
TMPDIR="$(mktemp -d)"
REMOTE_TARBALL="${x_REMOTE_SKEL_TARBALL:-https://codeload.github.com/xscriptor-colors/assets/tar.gz/refs/heads/main}"

if command -v curl >/dev/null 2>&1; then
  echo "[x] Downloading $REMOTE_TARBALL..."
  if curl -fsSL "$REMOTE_TARBALL" -o "$TMPDIR/x-assets.tar.gz"; then
    echo "[x] Extracting..."
    tar -xzf "$TMPDIR/x-assets.tar.gz" -C "$TMPDIR"
    
    # Find the extracted folder (github adds repo-branch/ prefix)
    REMOTE_ROOT="$(find "$TMPDIR" -maxdepth 2 -type d -name "x-assets-*" | head -n 1)"
    
    if [ -n "$REMOTE_ROOT" ] && [ -d "$REMOTE_ROOT/skel/.config" ]; then
      SKEL_SRC="$REMOTE_ROOT/skel/.config"
      echo "[x] Remote assets ready at $SKEL_SRC"
    else
      echo "[x] Warning: Could not find skel/.config in downloaded archive."
    fi
  else
    echo "[x] Warning: Download failed. Using local assets."
  fi
else
  echo "[x] Warning: curl not found."
fi

# Apply to /etc/skel (Future users)
echo "[x] Applying to /etc/skel..."
install -d /mnt/etc/skel/.config
# Copy contents recursively
cp -rT "$SKEL_SRC/" /mnt/etc/skel/.config/

# Apply to existing users (created by archinstall)
echo "[x] Applying to existing users..."
for user_home in /mnt/home/*; do
  [ -d "$user_home" ] || continue
  user_name=$(basename "$user_home")
  echo " -> $user_name"
  
  install -d "$user_home/.config"
  cp -rT "$SKEL_SRC/" "$user_home/.config/"
  
  # Fix permissions
  in_chroot "chown -R $user_name:$user_name /home/$user_name/.config"
done

# 6) GRUB & Bootloader Branding
echo "[x] Configuring Bootloader Branding..."

# Helper to rename entries
rename_boot_entries() {
  # systemd-boot
  # Initial rename
  for d in /mnt/boot/loader/entries /mnt/efi/loader/entries; do
    if [ -d "$d" ]; then
      for f in "$d"/*.conf; do
        [ -f "$f" ] && sed -i 's/Arch Linux/X/g' "$f" || true
      done
    fi
  done
  
  # GRUB
  if [ -f /mnt/etc/default/grub ]; then
    sed -i '/^GRUB_DISTRIBUTOR=/d' /mnt/etc/default/grub
    echo 'GRUB_DISTRIBUTOR="X"' >> /mnt/etc/default/grub
    
    # Verbose boot
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/d' /mnt/etc/default/grub
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7 systemd.show_status=1 rd.udev.log_priority=debug"' >> /mnt/etc/default/grub
    
    # Rebuild GRUB
    if in_chroot "command -v grub-mkconfig" >/dev/null 2>&1; then
      in_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
    fi
  fi


}


rename_boot_entries

# 7) Base Packages & Services
echo "[x] Installing additional tools..."
in_chroot "pacman -S --noconfirm --needed \
  git \
  wget \
  curl \
  helix \
  ptyxis \
  zellij \
  yazi \
  nodejs \
  zsh \
  docker \
  docker-compose \
  base-devel \
  obsidian \
  code \
  || true"

echo "[x] Enabling docker service..."
in_chroot "systemctl enable docker.service || true"

# 8) First Boot Service (Cleanup & Post-Install Script)
echo "[x] Setting up first-boot terminal hook..."

# 8.1 Create the script that runs on first terminal launch
install -d /mnt/usr/local/bin
cat > /mnt/usr/local/bin/x-first-terminal.sh <<'EOS'
#!/bin/sh
set -eu
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/x"
STATE="$STATE_DIR/firstterminal.done"
mkdir -p "$STATE_DIR"

# If already run, exit
[ -f "$STATE" ] && exit 0

printf "\n──────────────────────────────────────────\n"
printf "   Finalizing x Configuration\n"
printf "──────────────────────────────────────────\n\n"

# Enforce Wallpaper
WALL="/usr/share/backgrounds/x/x-wallpaper.png"
DESKTOP="${XDG_CURRENT_DESKTOP:-}"

if [ -f "$WALL" ]; then
    case "$DESKTOP" in
        *KDE*)
            if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
                echo "→ Applying KDE Wallpaper..."
                plasma-apply-wallpaperimage "$WALL" || true
            fi
            ;;
        *XFCE*)
            if command -v xfconf-query >/dev/null 2>&1; then
                echo "→ Applying XFCE Wallpaper..."
                # Set for all connected monitors on the default channel
                for property in $(xfconf-query -c xfce4-desktop -l | grep "last-image"); do
                    xfconf-query -c xfce4-desktop -p "$property" -s "$WALL" || true
                done
                for property in $(xfconf-query -c xfce4-desktop -l | grep "image-path"); do
                    xfconf-query -c xfce4-desktop -p "$property" -s "$WALL" || true
                done
            fi
            ;;
    esac
fi

# Wait for internet connection
printf "Waiting for internet connection..."
i=0
while ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; do
    sleep 1
    i=$((i+1))
    [ "$i" -ge 30 ] && break
done
echo " Done."

cd "$HOME" 2>/dev/null || cd /tmp

# Download and run the post-reboot script (x.sh)
TARGET_SCRIPT="https://raw.githubusercontent.com/xlnux/x/main/x.sh"
if curl -sLO "$TARGET_SCRIPT"; then
    chmod +x x.sh
    echo "→ Running post-install script (x.sh)..."
    ./x.sh || echo "Warning: x.sh returned error status."
else
    echo "Error: Failed to download x.sh"
fi

# Mark as done so it doesn't run again
touch "$STATE"

# Remove the Autostart entry
if [ -f "$HOME/.config/autostart/x-firstboot.desktop" ]; then
    rm -f "$HOME/.config/autostart/x-firstboot.desktop"
fi

echo
echo "x configuration finished."
sleep 3
exit 0
EOS
chmod +x /mnt/usr/local/bin/x-first-terminal.sh

# 8.2 Create the XDG Autostart entry
# We put it in skel so it is copied to new users, and can be deleted by the user script.
install -d /mnt/etc/skel/.config/autostart
cat > /mnt/etc/skel/.config/autostart/x-firstboot.desktop <<EOF
[Desktop Entry]
Type=Application
Name=x Setup
Comment=Finalize x Installation
Exec=ptyxis -- /usr/local/bin/x-first-terminal.sh
Icon=utilities-terminal
Terminal=false
StartupNotify=true
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# 8.3 Apply to existing users (created by archinstall)
for user_home in /mnt/home/*; do
  [ -d "$user_home" ] || continue
  user_name=$(basename "$user_home")
  
  install -d "$user_home/.config/autostart"
  cp /mnt/etc/skel/.config/autostart/x-firstboot.desktop "$user_home/.config/autostart/"
  chown -R "$user_name:$user_name" "$user_home/.config/autostart"
done

echo "[x] Post-install finished successfully."
exit 0
