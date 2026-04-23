# QEMU VM Launcher

Small **personal** helper for spinning up a Windows VM in QEMU when you need it—nothing more. No roadmap, no “product” support, no guarantees: use it, break it, fork it, ignore it.

Bash scripts to install QEMU + OVMF + swtpm (on Ubuntu-like distros) and boot a VM with UEFI + software TPM. Parts of the repo were refactored with AI assistance.

## Run

```bash
sudo bash launcher.sh
```

Needs **root** and **KVM**. Put your Windows `.iso` in `images/`. Disk images live in `os/ubuntu/volumes/` (created for you). `images/` and `tpm/` sit at the repo root — create them if missing: `mkdir -p images tpm`.

## New VM in short

1. Menu **1** — install packages  
2. Copy a Windows ISO into **`images/`**  
3. Menu **2** — create a raw disk (size in GB)  
4. Menu **3** — pick ISO + disk, install in the QEMU window  
5. Later use **4** to boot; **5** resizes the disk (VM off)

## Tweaks

Edit **`os/ubuntu/.env`** for RAM, CPU count, display, and paths.
