#!/usr/bin/env bash
set -Eeuo pipefail

# Launch the X live ISO (or an installed disk) in QEMU from the terminal.
# No libvirt/virtual networks involved: plain qemu-system-x86_64.
#
# Usage: ./vm.sh [options]
#
#   --iso PATH        ISO to boot (default: newest out/*.iso)
#   --disk PATH       qcow2 disk (default: $HOME/x-vm.qcow2; created 32G if missing)
#   --boot iso|disk   Boot the ISO (default) or the installed disk
#   --uefi            Use OVMF firmware (systemd-boot / UEFI installs)
#   --ram MB          Guest RAM in MiB (default: 6144)
#   --cpus N          Guest vCPUs (default: 4)
#   --no-kvm          Disable KVM acceleration
#   --display MODE    QEMU display backend (gtk, sdl, none, ...)
#   --ssh-port PORT   Forward host PORT -> guest 22 (e.g. 2222)
#   --seed            Attach an xauto seed disk built from --seed-json
#   --seed-json FILE  Install JSON for --seed (default: ./x-install.json)
#   --build           Run ./xbuild.sh (sudo) before booting
#   --deps            Install missing host packages (sudo pacman)
#   --print           Print the resolved QEMU command and exit
#   -h, --help        This help
#
# Examples:
#   ./vm.sh --deps                       # install archiso + qemu + OVMF
#   ./vm.sh --build                      # build the ISO and boot it (BIOS)
#   ./vm.sh --uefi --boot disk           # boot an installed UEFI disk
#   ./vm.sh --ssh-port 2222              # live ISO with SSH forward

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ISO=""
DISK="$HOME/x-vm.qcow2"
BOOT="iso"
UEFI=0
RAM=6144
CPUS=4
USE_KVM="auto"
DISPLAY_OPT=""
SSH_PORT=""
SEED=0
SEED_JSON=""
DO_BUILD=0
DO_DEPS=0
PRINT=0

DEPS=(archiso qemu-desktop edk2-ovmf dosfstools mtools)

usage() { sed -n '3,29p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'vm: %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --iso)       ISO="${2:?--iso needs a path}"; shift 2 ;;
        --disk)      DISK="${2:?--disk needs a path}"; shift 2 ;;
        --boot)      BOOT="${2:?--boot needs iso|disk}"; shift 2 ;;
        --uefi)      UEFI=1; shift ;;
        --ram)       RAM="${2:?--ram needs MiB}"; shift 2 ;;
        --cpus)      CPUS="${2:?--cpus needs a number}"; shift 2 ;;
        --no-kvm)    USE_KVM=0; shift ;;
        --display)   DISPLAY_OPT="${2:?--display needs a mode}"; shift 2 ;;
        --ssh-port)  SSH_PORT="${2:?--ssh-port needs a port}"; shift 2 ;;
        --seed)      SEED=1; shift ;;
        --seed-json) SEED=1; SEED_JSON="${2:?--seed-json needs a path}"; shift 2 ;;
        --build)     DO_BUILD=1; shift ;;
        --deps)      DO_DEPS=1; shift ;;
        --print)     PRINT=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           die "unknown argument '$1' (see --help)" ;;
    esac
done

[[ "$BOOT" == "iso" || "$BOOT" == "disk" ]] || die "--boot must be iso or disk"

# --- dependencies -----------------------------------------------------------
if [[ "$DO_DEPS" == "1" ]]; then
    log "installing host packages: ${DEPS[*]}"
    sudo pacman -S --needed --noconfirm "${DEPS[@]}"
fi

missing=()
for c in qemu-system-x86_64 qemu-img; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if (( ${#missing[@]} )); then
    die "missing ${missing[*]} — run: ./vm.sh --deps"
fi
if [[ "$DO_BUILD" == "1" ]] && ! command -v mkarchiso >/dev/null 2>&1; then
    die "mkarchiso is missing — run: ./vm.sh --deps"
fi

# --- ISO build --------------------------------------------------------------
if [[ "$DO_BUILD" == "1" ]]; then
    log "building the ISO (sudo $SELF_DIR/xbuild.sh)"
    (cd "$SELF_DIR" && sudo ./xbuild.sh)
fi

# --- resolve the ISO --------------------------------------------------------
if [[ "$BOOT" == "iso" && -z "$ISO" ]]; then
    ISO="$(ls -t "$SELF_DIR"/out/*.iso 2>/dev/null | head -1 || true)"
fi
if [[ "$BOOT" == "iso" ]]; then
    [[ -n "$ISO" && -f "$ISO" ]] || die "no ISO found in $SELF_DIR/out — build it with: sudo ./xbuild.sh (or ./vm.sh --build)"
    log "ISO: $ISO"
fi

# --- disk -------------------------------------------------------------------
if [[ "$BOOT" == "disk" && ! -f "$DISK" ]]; then
    die "disk not found: $DISK"
fi
if [[ "$BOOT" == "iso" && ! -f "$DISK" ]]; then
    if [[ "$PRINT" == "1" ]]; then
        log "disk missing; it would be created: qemu-img create -f qcow2 $DISK 32G"
    else
        log "creating disk $DISK (32G, qcow2)"
        qemu-img create -f qcow2 "$DISK" 32G >/dev/null
    fi
fi

# --- KVM --------------------------------------------------------------------
ACCEL=()
if [[ "$USE_KVM" != "0" ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
        ACCEL=(-enable-kvm -cpu host)
    elif [[ "$USE_KVM" == "auto" ]]; then
        warn "KVM not usable (/dev/kvm); running without acceleration"
    else
        die "KVM requested but /dev/kvm is not usable"
    fi
fi

# --- firmware (UEFI) --------------------------------------------------------
FW=()
VARS="$DISK.vars.fd"
if [[ "$UEFI" == "1" ]]; then
    CODE="${X_VM_OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
    VARS_SRC="${X_VM_OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"
    [[ -f "$CODE" && -f "$VARS_SRC" ]] || die "OVMF firmware not found — run: ./vm.sh --deps"
    if [[ ! -f "$VARS" ]]; then
        if [[ "$PRINT" == "1" ]]; then
            log "OVMF vars missing; they would be copied to $VARS"
        else
            cp "$VARS_SRC" "$VARS"
        fi
    fi
    FW=(-drive "file=$CODE,if=pflash,format=raw,readonly=on"
        -drive "file=$VARS,if=pflash,format=raw")
fi

# --- seed disk (xauto=1) ----------------------------------------------------
SEED_ARGS=()
if [[ "$SEED" == "1" ]]; then
    SEED_JSON="${SEED_JSON:-$SELF_DIR/x-install.json}"
    [[ -f "$SEED_JSON" ]] || die "seed JSON not found: $SEED_JSON (see docs/installer.md)"
    SEED_IMG="$DISK.cidata.img"
    if [[ "$PRINT" == "1" ]]; then
        log "seed disk would be built: $SEED_IMG (label cidata)"
    else
        log "building seed disk $SEED_IMG (label cidata)"
        qemu-img create -f raw "$SEED_IMG" 64M >/dev/null
        mkfs.vfat -n cidata "$SEED_IMG" >/dev/null
        mcopy -i "$SEED_IMG" "$SEED_JSON" ::x-install.json
        warn "add 'xauto=1' to the kernel cmdline at the boot menu to trigger the unattended install"
    fi
    SEED_ARGS=(-drive "file=$SEED_IMG,format=raw,if=virtio")
fi

# --- network ----------------------------------------------------------------
NET="user,id=net0"
[[ -n "$SSH_PORT" ]] && NET="$NET,hostfwd=tcp::$SSH_PORT-:22"

# --- assemble the QEMU command ---------------------------------------------
CMD=(qemu-system-x86_64
    "${ACCEL[@]}"
    -m "$RAM" -smp "$CPUS"
    "${FW[@]}"
)
if [[ "$BOOT" == "iso" ]]; then
    CMD+=(-cdrom "$ISO" -boot "order=d,menu=on")
else
    CMD+=(-boot "order=c,menu=on")
fi
CMD+=(-drive "file=$DISK,if=virtio,format=qcow2")
CMD+=("${SEED_ARGS[@]}")
CMD+=(-netdev "$NET" -device virtio-net-pci,netdev=net0)
[[ -n "$DISPLAY_OPT" ]] && CMD+=(-display "$DISPLAY_OPT")

if [[ "$PRINT" == "1" ]]; then
    printf '%q ' "${CMD[@]}"; printf '\n'
    exit 0
fi

log "starting QEMU (BIOS: ${BOOT}, UEFI: $UEFI, RAM: ${RAM}M, vCPUs: $CPUS, KVM: $([[ ${#ACCEL[@]} -gt 0 ]] && echo on || echo off))"
[[ -n "$SSH_PORT" ]] && log "SSH: ssh -p $SSH_PORT user@localhost (after install)"
exec "${CMD[@]}"
