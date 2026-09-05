# Installation

X Linux is installed from the **live ISO** using a **text installer** (no
graphical installer; Calamares was removed).

## Flow

1. The live environment boots to TTY1 and launches the installer (`/root/x-installer/`).
2. **Configurator** (`configurator.sh`): selects the disk, hostname, and user
   (UI via `gum`; falls back to plain prompts if unavailable). Writes `/tmp/x-install.json`.
3. **Installer** (`install.sh`):
   - Partitions (GPT: EFI 512M + btrfs) and mounts at `/mnt`.
   - `pacstrap`: base + live manifest (includes the `[x]` packages).
   - Configures locale/hostname, creates the user, and applies branding.
   - Provisions with the **`x-scripts`** package: system phases (`x setup`)
     and user phases (`x setup --user`; the Hyprland setup is deferred to first
     boot, `X_HYPRLAND=0` during installation).
   - Installs GRUB with `x` branding.

## Variables

- `script=<url|path>` on cmdline: automated installation (no configurator).
- `X_DRY=1`: shows the plan without touching anything.
- `X_SKIP_INSTALLER=1`: do not launch the installer at boot.
- `X_PKGLIST`: alternative package manifest (default `/run/archiso/...`).

## Notes

- Installation uses the official repos + `[x]` (requires network). The offline
  mirror bundled in the ISO is pending design (see the workspace ROADMAP).
- End-to-end validation in QEMU: pending (requires a VM environment).
