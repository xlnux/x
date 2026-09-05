# Instalación

X Linux se instala desde el **live ISO** con un **instalador en texto** (sin
instalador gráfico; Calamares fue eliminado).

## Flujo

1. El live arranca en TTY1 y lanza el instalador (`/root/x-installer/`).
2. **Configurador** (`configurator.sh`): selecciona disco, hostname y usuario
   (UI con `gum`; cae a prompts simples si no está). Escribe `/tmp/x-install.json`.
3. **Instalador** (`install.sh`):
   - Particiona (GPT: EFI 512M + btrfs) y monta en `/mnt`.
   - `pacstrap`: base + manifiesto del live (incluye los paquetes `[x]`).
   - Configura locale/hostname, crea el usuario y aplica branding.
   - Provisiona con el paquete **`x-scripts`**: fases de sistema (`x setup`)
     y de usuario (`x setup --user`; el setup de Hyprland se difiere al primer
     arranque, `X_HYPRLAND=0` durante la instalación).
   - Instala GRUB con branding `x`.

## Variables

- `script=<url|ruta>` en cmdline: instalación automatizada (sin configurador).
- `X_DRY=1`: muestra el plan sin tocar nada.
- `X_SKIP_INSTALLER=1`: no lanzar el instalador en el arranque.
- `X_PKGLIST`: manifiesto de paquetes alternativo (default `/run/archiso/...`).

## Notas

- La instalación usa los repos oficiales + `[x]` (requiere red). El mirror
  offline bundlado en la ISO está pendiente de diseño (ver ROADMAP del
  workspace).
- Validación end-to-end en QEMU: pendiente (requiere entorno de VM).
