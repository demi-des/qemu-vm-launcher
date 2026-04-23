#!/bin/bash

source .env
set -e


RAM=${RAM:-8}
REPO_PATH=${REPO_PATH:-~/Repository/toolbox/QEMU}

cd $REPO_PATH

while true; do
    echo ""
    echo "=== QEMU VM Launcher ==="
    echo ""
    echo "  1) Install or update QEMU, swtpm, and OVMF (apt)"
    echo "  2) Create a new virtual disk image (raw, in ./volumes/)"
    echo "  3) Create and boot a Windows VM (ISO + disk; first-time setup)"
    echo "  4) Boot an existing Windows VM"
    echo "  5) Resize / extend a virtual disk (qemu-img; VM must be off)"
    echo "  0) Exit"
    echo ""
    read -rp "Select an option [0-5]: " user_input
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
        echo "The volume will be created inside this folder."
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

        cd ./volumes/

        echo "Creating a new Virtual Volume"
        qemu-img create -f raw $virtual_volume_name ${virtual_volume_size}G
        echo ""

        cd ..

        echo "New Virtual Volume created"
        ;;
    3)
        echo "Creating and starting a WINDOWS virtual machine"
        echo "The virtual machine will have $RAM GB of RAM"
        echo "If you want to change the value edit the script ubuntu.sh"
        echo ""
        echo "Here is the link to the Windows ISO file:"
        echo "https://www.microsoft.com/en-us/software-download/windows11"
        echo ""        
        echo ""
        
        echo "ISO list from directory ./iso/"
        ls ./iso/
        echo ""

        echo "Enter the name of the ISO file <wholeName.iso"
        read -p ">" iso_file_name
        echo ""
        echo ""

        echo "Disk list"
        ls ./volumes/
        echo ""

        echo "Enter the name of the Virtual Volume"
        read -p ">" virtual_volume_name
        echo ""        
        echo ""

        echo "Copying OVMF_VARS.fd to ./tpm/OVMF_VARS_win11.fd"
        cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd ./tpm/OVMF_VARS_win11.fd
        echo ""

        echo "Starting TPM emulator"
        # Stop any previous swtpm and remove stale socket/lock
        pkill swtpm 2>/dev/null || true
        rm -f ./tpm/swtpm-sock 2>/dev/null || true
        rm -f ./tpm/lock 2>/dev/null || true
        
        swtpm socket --tpmstate dir=./tpm/ \
            --ctrl type=unixio,path=./tpm/swtpm-sock \
            --tpm2 \
            --daemon
        echo ""
        echo ""
        sleep 2

        echo "Now the virtual machine will be started."
        echo "If you just needed the TPM emulator, quit the script"
        echo ""
        read -p "Press Enter to start the virtual machine" 
        echo ""     

        taskset -c 2-4 qemu-system-x86_64 \
            -machine q35,smm=on,accel=kvm \
            -m ${RAM}G \
            -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
            -drive if=pflash,format=raw,file=./tpm/OVMF_VARS_win11.fd \
            -device ich9-ahci,id=ahci \
            -drive id=disk,if=none,file=./volumes/$virtual_volume_name,format=raw \
            -device ide-hd,bus=ahci.1,drive=disk,bootindex=1 \
            -drive id=cd,if=none,format=raw,readonly=on,file=./iso/$iso_file_name \
            -device ide-cd,bus=ahci.2,drive=cd,bootindex=0 \
            -chardev socket,id=chrtpm,path=./tpm/swtpm-sock \
            -tpmdev emulator,id=tpm0,chardev=chrtpm \
            -device tpm-tis,tpmdev=tpm0 \
            -boot order=d,menu=on \
            -cpu host \
            -smp 2 \
            -vga std \
            -display sdl \
    
        ;;
    4)
        echo "Booting a WINDOWS virtual machine already created..."
        echo ""
        echo "The virtual machine will have $RAM GB of RAM"
        echo "If you want to change the value edit the script ubuntu.sh"
        echo ""
        echo "If it's the first time you boot on windows, and you don't want to use a microsoft account,"
        echo "you can use the following command to skip the login screen (shift + F10 to open the terminal)"
        echo "  start ms-cxh:localonly"
        echo ""

        echo "Disk list"
        ls ./volumes/
        echo ""

        echo "Enter the name of the Virtual Volume"
        read -p ">" virtual_volume_name
        echo ""
        echo ""

        echo "Starting TPM emulator..."
        # Stop any previous swtpm and remove stale socket/lock
        pkill swtpm 2>/dev/null || true
        rm -f ./tpm/swtpm-sock 2>/dev/null || true
        rm -f ./tpm/lock 2>/dev/null || true
        
        swtpm socket --tpmstate dir=./tpm/ \
            --ctrl type=unixio,path=./tpm/swtpm-sock \
            --tpm2 \
            --daemon
        sleep 2

        echo "Starting the virtual machine..."

        taskset -c 2-4 qemu-system-x86_64 \
            -machine q35,smm=on,accel=kvm \
            -m ${RAM}G \
            -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
            -drive if=pflash,format=raw,file=./tpm/OVMF_VARS_win11.fd \
            -device ich9-ahci,id=ahci \
            -drive id=disk,if=none,file=./volumes/$virtual_volume_name,format=raw \
            -device ide-hd,bus=ahci.1,drive=disk,bootindex=0 \
            -chardev socket,id=chrtpm,path=./tpm/swtpm-sock \
            -tpmdev emulator,id=tpm0,chardev=chrtpm \
            -device tpm-tis,tpmdev=tpm0 \
            -boot menu=on \
            -cpu host \
            -smp 2 \
            -vga std \
            -display sdl
        ;;
    5)
        echo "Extend / Resize a Virtual Volume (RAW)"
        echo ""
        echo "IMPORTANT: make sure the VM is powered off before resizing the disk image."
        echo ""
        echo "Disk list"
        ls ./volumes/
        echo ""

        echo "Enter the name of the Virtual Volume (file inside ./volumes/)"
        read -p ">" virtual_volume_name
        echo ""

        if [ ! -f "./volumes/$virtual_volume_name" ]; then
            echo "Disk image not found: ./volumes/$virtual_volume_name"
            echo ""
            read -p "Press Enter to exit"
            echo ""
            exit 1
        fi

        echo "Current disk info:"
        qemu-img info "./volumes/$virtual_volume_name" || true
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

        echo "Resizing ./volumes/$virtual_volume_name to ${virtual_volume_size}G ..."
        qemu-img resize "./volumes/$virtual_volume_name" "${virtual_volume_size}G"
        echo ""

        echo "Updated disk info:"
        qemu-img info "./volumes/$virtual_volume_name" || true
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
