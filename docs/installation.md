# Instalación con Calamares

X Linux se instala con **Calamares**, el instalador gráfico estándar usado por
Manjaro, EndeavourOS, CachyOS y Garuda. No se usa `archinstall`.

## Flujo

El live ISO arranca en una **sesión gráfica mínima** (openbox + pcmanfm) con un
icono **"Instalar X"** en el escritorio. Al hacer clic se abre Calamares.

Componentes:

- `calamares` — el instalador (compilado desde AUR, alojado en `x-repo`).
- `x-calamares-config` — configuración de módulos y branding de X.
- `x-live-session` — sesión gráfica del live (openbox, pcmanfm, icono).

## Módulos habilitados

| Fase | Módulo | Función |
|------|--------|---------|
| show | welcome | Bienvenida, requisitos (disco/RAM/red) |
| show | locale | Idioma, zona horaria, formato |
| show | keyboard | Distribución de teclado |
| show | partition | Particionado (btrfs por defecto, EFI, swap) |
| show | users | Usuario, contraseña, sudo, autologin |
| show | summary | Resumen antes de instalar |
| exec | partition / mount | Aplicar particionado y montar |
| exec | unpackfs | Copiar el sistema X embebido (offline) |
| exec | machineid / fstab / locale / keyboard / localecfg | Configuración base |
| exec | users / displaymanager | Usuario y GDM |
| exec | networkcfg / hwclock / services-systemd | Red, reloj, servicios (docker) |
| exec | initcpiocfg / initcpio | Initramfs (systemd) |
| exec | grubcfg / bootloader | GRUB con branding X |
| exec | shellprocess | `x-release-apply` (identidad final) |
| show | finished | Reboot |

## Instalación offline

La ISO usa el módulo `unpackfs`: el sistema X completo (con GNOME, branding y
paquetes X) va embebido en `airootfs.sfs` y se copia al disco. **No requiere
red** para la instalación base.

## Configuración por defecto

- Bootloader: GRUB (UEFI + BIOS)
- Sistema de ficheros: btrfs (con opción swap)
- Escritorio: GNOME + GDM
- Usuario: se pide durante la instalación (nada hardcodeado)
- Repos: oficiales + `[x]` (x-repo)

## Notas

- `SigLevel = Optional TrustAll` para `[x]` es de desarrollo; endurecer con
  firmas antes de release.
- Calamares se compila una vez desde AUR (`calamares`, `kpmcore-git`) y se
  publica en `x-repo/public/repo/x86_64/`.
