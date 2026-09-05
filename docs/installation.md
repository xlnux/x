# Instalación

La vía de instalación gráfica basada en **Calamares** se eliminó. La instalación y el
aprovisionamiento del sistema se rehacen por **scripts** (estilo Omarchy) dentro de la
iniciativa *reboot*.

## Estado

- El live ISO arranca sin instalador gráfico (sin `x-calamares-config`, `x-live-session` ni
  los paquetes `calamares`/`kpmcore-git`).
- El flujo de instalación por scripts (configurador en texto + setup de sistema/usuario) está
  en desarrollo; las decisiones y fases se documentan en `DECISIONS.md` y `ROADMAP.md` de la
  raíz del workspace `x-lnux`.
