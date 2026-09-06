# Testing X Linux in a VM

Helper commands to run the X Linux ISO and boot an installed disk with QEMU.
Adjust paths (`ISO`, `DISK`) to your machine.

```bash
ISO=/home/x0z/Documents/repos/x-lnux/x/out/x-2026.09.06-x86_64.iso
DISK=/home/x0z/x-vm.qcow2
```

## Create a target disk (first time)

```bash
qemu-img create -f qcow2 "$DISK" 32G
```

## Boot the ISO (install / live, BIOS)

```bash
qemu-system-x86_64 -enable-kvm -m 6144 -smp 4 -cpu host \
  -cdrom "$ISO" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -boot d
```

The text installer runs automatically on the first tty1 login. Shortcut
(alias) if you are dropped to a shell:

```bash
alias xinstall='bash /root/x-installer/installer.sh'
xinstall
```

## Boot the installed disk (BIOS boot: GRUB)

```bash
qemu-system-x86_64 -enable-kvm -m 6144 -smp 4 -cpu host \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -boot c
```

## Boot the installed disk (UEFI: systemd-boot or GRUB EFI)

```bash
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/ovmf_vars.fd

qemu-system-x86_64 -enable-kvm -m 6144 -smp 4 -cpu host \
  -drive file=/usr/share/edk2/x64/OVMF_CODE.4m.fd,if=pflash,format=raw,readonly=on \
  -drive file=/tmp/ovmf_vars.fd,if=pflash,format=raw \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0
```

Notes:

- The installer writes both a BIOS boot (GRUB + `bios_grub` partition) and a
  UEFI boot path when **GRUB** is selected, so either boot works.
- **systemd-boot** is UEFI-only: boot the disk with the OVMF command above.
- `-netdev user` (slirp) provides NAT without libvirt/virtual networks.
- On hosts whose kernel lacks the `htb` qdisc (e.g. custom builds), libvirt's
  `default` network and VirtualBox host modules may fail; direct QEMU above
  avoids both.
