#!/bin/bash

UBUNTU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$UBUNTU_DIR")")"

source "$UBUNTU_DIR/.env"
set -e

RAM=${RAM:-8}
QEMU_SMP=${QEMU_SMP:-2}
QEMU_CPU=${QEMU_CPU:-host}
QEMU_VGA=${QEMU_VGA:-std}
QEMU_DISPLAY=${QEMU_DISPLAY:-sdl}
QEMU_CPU_AFFINITY=${QEMU_CPU_AFFINITY:-2-4}
OVMF_CODE_FD=${OVMF_CODE_FD:-/usr/share/OVMF/OVMF_CODE_4M.secboot.fd}
OVMF_VARS_TEMPLATE=${OVMF_VARS_TEMPLATE:-/usr/share/OVMF/OVMF_VARS_4M.ms.fd}
VOLUMES_DIR=${VOLUMES_DIR:-volumes}
ISO_DIR=${ISO_DIR:-images}
TPM_DIR=${TPM_DIR:-tpm}
OVMF_VARS_WIN=${OVMF_VARS_WIN:-OVMF_VARS_win11.fd}

# Disk images live next to this script: os/ubuntu/<VOLUMES_DIR>/
VOLUMES_ROOT="$UBUNTU_DIR/$VOLUMES_DIR"
mkdir -p "$VOLUMES_ROOT"

cd "$REPO_ROOT"

_qemu() {
    if [ "$QEMU_CPU_AFFINITY" = "off" ] || [ "$QEMU_CPU_AFFINITY" = "false" ]; then
        qemu-system-x86_64 "$@"
    else
        taskset -c "$QEMU_CPU_AFFINITY" qemu-system-x86_64 "$@"
    fi
}

while true; do
    cd "$REPO_ROOT"

    echo ""
    sleep 0.1
    echo "=== QEMU VM Launcher ==="
    sleep 0.1
    echo ""
    sleep 0.1
    echo "  1) Install or update QEMU, swtpm, and OVMF (apt)"
    sleep 0.1
    echo "  2) Create a new virtual disk image (raw, in os/ubuntu/$VOLUMES_DIR/)"
    sleep 0.1
    echo "  3) Create and boot a Windows VM (ISO + disk; first-time setup)"
    sleep 0.1
    echo "  4) Boot an existing Windows VM"
    sleep 0.1
    echo "  5) Resize / extend a virtual disk (qemu-img; VM must be off)"
    sleep 0.1
    echo "  0) Exit"
    sleep 0.1
    echo ""
    read -rp "Select an option [0-5]: " user_input
    sleep 0.1
    echo ""

    case $user_input in
        0)
            echo "Goodbye."
            exit 0
            ;;
    1)
        echo "Installing / Updating QEMU"
        echo ""
        sudo apt update
        sudo apt install qemu-system -y
        sudo apt install swtpm -y
        sudo apt install ovmf -y
        ;;
    2)
        echo "Creating a Virtual Volume"
        echo ""
        echo "The volume will be created in: $VOLUMES_ROOT"
        echo "The volume and the temp files are inside the .gitignore, so it will not be pushed to the repository."
        echo ""
        echo ""
        echo "Enter the name of the new Virtual Volume"
        read -p ">" virtual_volume_name
        echo ""
        echo "Enter the size of the new Virtual Volume !!! -> in GB"
        read -p ">" virtual_volume_size
        echo ""
        echo ""

        if ! [[ "$virtual_volume_size" =~ ^[0-9]+$ ]]; then
            echo "The volume size must be a positive integer without any letters"
            echo "You entered: $virtual_volume_size"
            echo ""
            read -p "Press Enter to exit"
            echo ""
            exit 1
        fi

        mkdir -p "$VOLUMES_ROOT"
        cd "$VOLUMES_ROOT"

        echo "Creating a new Virtual Volume"
        qemu-img create -f raw "$virtual_volume_name" "${virtual_volume_size}G"
        echo ""

        cd "$REPO_ROOT"

        echo "New Virtual Volume created"
        ;;
    3)
        echo "Creating and starting a WINDOWS virtual machine"
        echo "The virtual machine will have $RAM GB of RAM"
        echo "To change RAM, edit $UBUNTU_DIR/.env (RAM=...)"
        echo ""
        echo "Here is the link to the Windows ISO file:"
        echo "https://www.microsoft.com/en-us/software-download/windows11"
        echo ""        
        echo ""
        
        mkdir -p "$REPO_ROOT/$ISO_DIR"
        echo "ISO list from directory $REPO_ROOT/$ISO_DIR/"
        ls "$REPO_ROOT/$ISO_DIR/"
        echo ""

        echo "Enter the name of the ISO file <wholeName.iso"
        read -p ">" iso_file_name
        echo ""
        echo ""

        echo "Disk list"
        ls "$VOLUMES_ROOT/"
        echo ""

        echo "Enter the name of the Virtual Volume"
        read -p ">" virtual_volume_name
        echo ""        
        echo ""

        mkdir -p "$REPO_ROOT/$TPM_DIR"
        echo "Copying OVMF vars template to $REPO_ROOT/$TPM_DIR/$OVMF_VARS_WIN"
        cp "$OVMF_VARS_TEMPLATE" "$REPO_ROOT/$TPM_DIR/$OVMF_VARS_WIN"
        echo ""

        echo "Starting TPM emulator"
        # Stop any previous swtpm and remove stale socket/lock
        pkill swtpm 2>/dev/null || true
        rm -f "$REPO_ROOT/$TPM_DIR/swtpm-sock" 2>/dev/null || true
        rm -f "$REPO_ROOT/$TPM_DIR/lock" 2>/dev/null || true
        
        swtpm socket --tpmstate dir="$REPO_ROOT/$TPM_DIR/" \
            --ctrl type=unixio,path="$REPO_ROOT/$TPM_DIR/swtpm-sock" \
            --tpm2 \
            --daemon
        echo ""
        echo ""
        sleep 2

        echo "Now the virtual machine will be started."
        echo "If you just needed the TPM emulator, quit the script"
        echo ""
        echo "Boot order is automatic: first start from ISO, later reboots from disk (no UEFI menu needed)."
        echo "If you see 'Press any key to boot from CD...' that is Windows — press Space once inside the QEMU window."
        echo ""
        read -p "Otherwise, press Enter to continue and start the virtual machine"
        echo ""
        echo "Tip — first-time Windows setup without a Microsoft account: at the network/sign-in screen,"
        echo "press Shift+F10 to open a console, then run:"
        echo "  OOBE\\BypassNRO.cmd"
        echo "After reboot, choose \"I don't have internet\" / limited setup and create a local account."
        echo "On some builds you can use instead: start ms-cxh:localonly"
        echo ""

        # CD on SATA port 0 + media=cdrom: OVMF often skips ISO if CD is only on a higher port
        _qemu \
            -machine q35,smm=on,accel=kvm \
            -m "${RAM}G" \
            -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_FD" \
            -drive if=pflash,format=raw,file="$REPO_ROOT/$TPM_DIR/$OVMF_VARS_WIN" \
            -device ich9-ahci,id=ahci \
            -drive id=cd,if=none,media=cdrom,format=raw,readonly=on,file="$REPO_ROOT/$ISO_DIR/$iso_file_name" \
            -device ide-cd,bus=ahci.0,drive=cd,bootindex=0 \
            -drive id=disk,if=none,file="$VOLUMES_ROOT/$virtual_volume_name",format=raw \
            -device ide-hd,bus=ahci.1,drive=disk,bootindex=1 \
            -chardev socket,id=chrtpm,path="$REPO_ROOT/$TPM_DIR/swtpm-sock" \
            -tpmdev emulator,id=tpm0,chardev=chrtpm \
            -device tpm-tis,tpmdev=tpm0 \
            -boot order=c,once=d,menu=on \
            -cpu "$QEMU_CPU" \
            -smp "$QEMU_SMP" \
            -vga "$QEMU_VGA" \
            -display "$QEMU_DISPLAY"

        ;;
    4)
        echo "Booting a WINDOWS virtual machine already created..."
        echo ""
        echo "The virtual machine will have $RAM GB of RAM"
        echo "To change RAM, edit $UBUNTU_DIR/.env (RAM=...)"
        echo ""
        echo "If it's the first time you boot on windows, and you don't want to use a microsoft account,"
        echo "you can use the following command to skip the login screen (shift + F10 to open the terminal)"
        echo "  start ms-cxh:localonly"
        echo ""

        echo "Disk list"
        ls "$VOLUMES_ROOT/"
        echo ""

        echo "Enter the name of the Virtual Volume"
        read -p ">" virtual_volume_name
        echo ""
        echo ""

        echo "Starting TPM emulator..."
        # Stop any previous swtpm and remove stale socket/lock
        pkill swtpm 2>/dev/null || true
        rm -f "$REPO_ROOT/$TPM_DIR/swtpm-sock" 2>/dev/null || true
        rm -f "$REPO_ROOT/$TPM_DIR/lock" 2>/dev/null || true
        
        swtpm socket --tpmstate dir="$REPO_ROOT/$TPM_DIR/" \
            --ctrl type=unixio,path="$REPO_ROOT/$TPM_DIR/swtpm-sock" \
            --tpm2 \
            --daemon
        sleep 2

        echo "Starting the virtual machine..."

        _qemu \
            -machine q35,smm=on,accel=kvm \
            -m "${RAM}G" \
            -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_FD" \
            -drive if=pflash,format=raw,file="$REPO_ROOT/$TPM_DIR/$OVMF_VARS_WIN" \
            -device ich9-ahci,id=ahci \
            -drive id=disk,if=none,file="$VOLUMES_ROOT/$virtual_volume_name",format=raw \
            -device ide-hd,bus=ahci.0,drive=disk,bootindex=0 \
            -chardev socket,id=chrtpm,path="$REPO_ROOT/$TPM_DIR/swtpm-sock" \
            -tpmdev emulator,id=tpm0,chardev=chrtpm \
            -device tpm-tis,tpmdev=tpm0 \
            -boot order=c,menu=on \
            -cpu "$QEMU_CPU" \
            -smp "$QEMU_SMP" \
            -vga "$QEMU_VGA" \
            -display "$QEMU_DISPLAY"
        ;;
    5)
        echo "Extend / Resize a Virtual Volume (RAW)"
        echo ""
        echo "IMPORTANT: make sure the VM is powered off before resizing the disk image."
        echo ""
        echo "Disk list"
        ls "$VOLUMES_ROOT/"
        echo ""

        echo "Enter the name of the Virtual Volume (file inside $VOLUMES_DIR/)"
        read -p ">" virtual_volume_name
        echo ""

        if [ ! -f "$VOLUMES_ROOT/$virtual_volume_name" ]; then
            echo "Disk image not found: $VOLUMES_ROOT/$virtual_volume_name"
            echo ""
            read -p "Press Enter to exit"
            echo ""
            exit 1
        fi

        echo "Current disk info:"
        qemu-img info "$VOLUMES_ROOT/$virtual_volume_name" || true
        echo ""

        echo "Enter the NEW total size of the Virtual Volume !!! -> in GB (example: 150)"
        read -p ">" virtual_volume_size
        echo ""

        if ! [[ "$virtual_volume_size" =~ ^[0-9]+$ ]]; then
            echo "The volume size must be a positive integer without any letters"
            echo "You entered: $virtual_volume_size"
            echo ""
            read -p "Press Enter to exit"
            echo ""
            exit 1
        fi

        echo "Resizing $VOLUMES_ROOT/$virtual_volume_name to ${virtual_volume_size}G ..."
        qemu-img resize "$VOLUMES_ROOT/$virtual_volume_name" "${virtual_volume_size}G"
        echo ""

        echo "Updated disk info:"
        qemu-img info "$VOLUMES_ROOT/$virtual_volume_name" || true
        echo ""
        echo "NOTE: inside Windows you must extend the partition to use the new unallocated space."
        ;;
    *)
        echo "Invalid option. Enter a number from 0 to 5."
        ;;
    esac

    echo ""
    read -rp "Press Enter to return to the menu..."
    echo ""
done
