#!/bin/bash

set -e
if [ "$EUID" -ne 0 ]; then
    echo "You must be root to execute this script"
    exit 1
fi


LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f /etc/os-release ]; then
    OS_NAME=$(grep -m1 '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
    OS_ID=$(grep -m1 '^ID=' /etc/os-release | cut -d= -f2- | tr -d '"' | tr '[:upper:]' '[:lower:]')
else
    OS_NAME="Unknown"
    OS_ID="unknown"
fi

"$LAUNCHER_DIR/resources/logo.sh"

case "$OS_ID" in
    ubuntu|pop|linuxmint|zorin|elementary|neon|kubuntu|lubuntu|xubuntu)
        OS_DIR="$LAUNCHER_DIR/os/ubuntu"
        OS_ENTRY="ubuntu.sh"
        ;;
    debian|devuan)
        OS_DIR="$LAUNCHER_DIR/os/debian"
        OS_ENTRY="debian.sh"
        ;;
    fedora|nobara|ultramarine)
        OS_DIR="$LAUNCHER_DIR/os/fedora"
        OS_ENTRY="fedora.sh"
        ;;
    rhel|centos|rocky|almalinux|ol)
        OS_DIR="$LAUNCHER_DIR/os/rhel"
        OS_ENTRY="rhel.sh"
        ;;
    arch|manjaro|endeavouros|garuda)
        OS_DIR="$LAUNCHER_DIR/os/arch"
        OS_ENTRY="arch.sh"
        ;;
    opensuse-leap|opensuse-tumbleweed|sle|sled|sles)
        OS_DIR="$LAUNCHER_DIR/os/opensuse"
        OS_ENTRY="opensuse.sh"
        ;;
    alpine)
        OS_DIR="$LAUNCHER_DIR/os/alpine"
        OS_ENTRY="alpine.sh"
        ;;
    gentoo)
        OS_DIR="$LAUNCHER_DIR/os/gentoo"
        OS_ENTRY="gentoo.sh"
        ;;
    void)
        OS_DIR="$LAUNCHER_DIR/os/void"
        OS_ENTRY="void.sh"
        ;;
    *)
        OS_DIR=""
        OS_ENTRY=""
        ;;
esac

if [ -z "$OS_DIR" ] || [ ! -f "$OS_DIR/$OS_ENTRY" ]; then
    echo "Unsupported OS: $OS_NAME (id: $OS_ID)"
    exit 1
fi

cd "$OS_DIR"

bash "$OS_ENTRY"
