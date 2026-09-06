# X Distribution — Roadmap

A comprehensive roadmap for the X Linux distribution, an Arch-based spin with its own package repository.

---

## Phase 1: Branding & Identity <!-- phase:branding -->

- [x] System identity (`/etc/os-release`) (#1)
- [x] GRUB distributor name (`GRUB_DISTRIBUTOR="X"`) (#2)
- [x] Bootloader menu entries (GRUB, systemd-boot, syslinux) (#3)
- [x] Fastfetch configuration (#4)
- [x] ISO profile (`profiledef.sh`) (#5)
- [x] MOTD (Message of the Day) (#6)

---

## Phase 2: Package Repository <!-- phase:package-repo -->

- [x] Create `x-release` PKGBUILD (#7)
- [x] Create install hooks (#8)
- [x] Add repository to `pacman.conf` (#9)
- [ ] Build package with `./build-repo.sh` (#10)
- [ ] Create `x-repo` repository on GitHub (#11)
- [ ] Upload package files to GitHub Releases (tag: `latest`) (#12)
- [ ] Test ISO build with package (#13)
- [ ] Migrate additional tools to the x repository (#14)

---

## Phase 3: Installation Experience <!-- phase:installation -->

- [x] Archinstall configuration (`user_configuration.json`) (#15)
- [x] Automated installation (`x-autostart.sh`) (#16)
- [x] Post-install branding (`x-postinstall.sh`) (#17)
- [ ] Custom installer UI (future) (#18)
- [ ] Welcome app on first boot (future) (#19)

---

## Phase 4: Desktop Environment <!-- phase:desktop-env -->

- [x] GNOME branding (wallpaper, GDM logo) (#20)
- [x] KDE Plasma branding (#21)
- [x] XFCE branding (#22)
- [x] Display manager configuration (GDM, SDDM, LightDM) (#23)
- [ ] Custom theme/icons (future) (#24)
- [ ] Default application configuration (#25)

---

## Phase 5: Documentation & Website <!-- phase:docs -->

- [ ] Landing page at `xscriptor.io/x` (#26)
- [ ] Installation guide (#27)
- [ ] FAQ / Troubleshooting (#28)
- [ ] Release notes template (#29)

---

## Phase 6: Release Pipeline <!-- phase:release -->

- [ ] Automated ISO builds (GitHub Actions / GitLab CI) (#30)
- [ ] Package signing with GPG (#31)
- [ ] Release versioning strategy (#32)
- [ ] Mirror setup (optional) (#33)

---

## Quick Start Commands

```bash
# Build the x-release package
cd x-packages
./build-repo.sh

# Build the ISO
cd /path/to/x
./xbuild.sh

# Build a WSL tarball
sudo ./xbuildwsl.sh
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `profiledef.sh` | ISO metadata and build settings |
| `pacman.conf` | Package manager configuration with x repo |
| `packages.x86_64` | Packages included in the ISO |
| `airootfs/etc/os-release` | System identity |
| `airootfs/etc/default/grub` | GRUB configuration |
| `xbuild.sh` | ISO build script |
| `xbuildwsl.sh` | WSL tarball build script |
