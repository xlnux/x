# X Linux — Roadmap de restructuración del instalador

Objetivo: sustituir el flujo basado en `archinstall` por un **instalador gráfico
(Calamares)** con branding propio, eliminar todas las descargas remotas de
assets/scripts, y centralizar la identidad en paquetes de `x-repo`.

Reglas: las ISOs se compilan en local (sin CI). Calamares se compila desde AUR
una vez y se aloja en `x-repo`.

---

## Etapa 0 — Diagnóstico de la máquina ✅
- [x] Verificar entorno (OS, herramientas, red, espacio).
- [x] Confirmar que la máquina ya corre X Linux.
- [x] Instalar `archiso` para builds locales.

## Etapa 1 — Limpieza de assets y descargas remotas
- [x] Empaquetar assets (wallpaper, logo, skel) en `x-release` (XBUILD + PKGBUILD).
- [x] Reescribir `x-postinstall.sh`: sin descargas remotas, usa solo assets instalados.
- [x] Alinear dconf del live a rutas del paquete; eliminar assets duplicados del airootfs.
- [x] Eliminar la descarga de `x.sh` en el primer arranque (`x-first-terminal.sh` → `x-dev-env` local).
- [ ] Publicar `x-dev` en el repo público (`x-repo/public/repo/x86_64/`).

## Etapa 2 — Branding con fuente única
- [x] Mover hooks de branding al paquete `x-release` (sobreviven upgrades de `filesystem`/`grub`).
- [x] Eliminar hooks duplicados y `os-release` estático del airootfs.
- [x] Unificar contenido: `x-release` es la única fuente de os-release/GRUB.
- [ ] Alinear URLs de `os-release` (xscriptor.io vs dev.xscriptor.com) en sistemas ya instalados.

## Etapa 3 — Calamares
- [x] Crear paquete `x-calamares-config` (settings, branding X, 21 módulos) — compilado y publicado.
- [x] Secuencia con `unpackfs`: sistema X embebido en la ISO (instalación offline).
- [ ] Compilar `calamares` + `kpmcore-git` desde AUR y publicar en `x-repo` (necesita sudo).
- [ ] Añadir `calamares` como dependencia de `x-calamares-config` en el repo.

## Etapa 4 — Sesión live gráfica
- [x] Crear paquete `x-live-session` (openbox + pcmanfm + icono "Instalar X") — compilado y publicado.
- [x] Arranque del live: `.zlogin` → `x-live-session` (startx + openbox) en vez de archinstall en TTY.
- [x] Eliminar `x-autostart.sh` y autologin TTY como flujo principal.

## Etapa 5 — Integración en x-linux
- [x] `packages.x86_64`: añadir `calamares`, `x-calamares-config`, `x-live-session`; quitar `archinstall`.
- [x] Eliminar `x-autostart.sh`, configs JSON de archinstall, creds.
- [x] Actualizar `profiledef.sh`, `.automated_script.sh`, `xbuildwslc.sh`.
- [ ] Escribir doc de instalación con Calamares (sustituye a default-installation.md).

## Etapa 6 — Verificación
- [x] Shellcheck/sintaxis bash de todos los scripts.
- [x] Validación YAML de la config de Calamares.
- [x] Integridad del repo local (db con 5 paquetes).
- [ ] Build ISO local (`./xbuild.sh`) y prueba en VM.
- [ ] Compilar `calamares` + `kpmcore-git` (binario) y publicar en `x-repo`.
