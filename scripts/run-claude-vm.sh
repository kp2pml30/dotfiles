#!/usr/bin/env bash
set -exuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="$FLAKE_DIR/.claude-vm"
DISK="$VM_DIR/disk.qcow2"
DISK_SIZE="20G"
RAM="12G"
CPUS="8"
SSH_PORT="2222"

mkdir -p "$VM_DIR"

qemu_base_args=(
	-machine q35
	-cpu host
	-enable-kvm
	-m "$RAM"
	-smp "$CPUS"
	-drive "file=$DISK,format=qcow2,if=virtio"
	-device virtio-net-pci,netdev=net0
	-netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
	-nographic
	-fsdev local,id=fsdev0,path=$VM_DIR/share,security_model=passthrough -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare
)

do_install() {
	echo "=== Building installer ISO... ==="
	ISO_PATH=$(nix build "${FLAKE_DIR}#nixosConfigurations.claude-vm-installer.config.system.build.isoImage" --no-link --print-out-paths)
	ISO_FILE=$(find "$ISO_PATH/iso" -name '*.iso' | head -1)

	if [ -z "$ISO_FILE" ]; then
		echo "Error: ISO not found after build"
		exit 1
	fi

	echo "ISO: $ISO_FILE"

	# Create fresh disk
	rm -f "$DISK"
	qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"

	echo "=== Booting installer (fully automatic)... ==="
	qemu-system-x86_64 \
		"${qemu_base_args[@]}" \
		-cdrom "$ISO_FILE" \
		-boot d

	echo "=== Installation finished. Run without --install to boot the VM. ==="
}

do_run() {
	if [ ! -f "$DISK" ]; then
		echo "No disk image found. Run with --install first."
		exit 1
	fi

	echo "=== Booting claude-vm (SSH: localhost:${SSH_PORT}) ==="
	qemu-system-x86_64 \
		"${qemu_base_args[@]}"
}

case "${1:-}" in
	--install)
		do_install
		;;
	--run)
		do_run
		;;
	"")
		if [ ! -f "$DISK" ]; then
			do_install
		fi
		do_run
		;;
	*)
		echo "Usage: $0 [--install|--run]"
		echo "  --install  Build ISO and install to disk"
		echo "  --run      Boot installed disk"
		echo "  (none)     Install if needed, then run"
		exit 1
		;;
esac
