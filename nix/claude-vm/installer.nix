{ pkgs, lib, rootPath, modulesPath, ... }:
let
	install-claude-vm = pkgs.writeShellScriptBin "install-claude-vm" ''
		set -euo pipefail

		DISK="/dev/vda"

		echo "=== claude-vm installer ==="
		echo "Target disk: $DISK"

		# Partition: MBR with single root partition
		echo "Partitioning..."
		parted -s "$DISK" -- \
			mklabel msdos \
			mkpart primary ext4 1MiB 100%

		# Format with label
		echo "Formatting..."
		mkfs.ext4 -L nixos "''${DISK}1"

		# Mount
		echo "Mounting..."
		mount "''${DISK}1" /mnt

		# Copy flake source
		echo "Copying flake to /mnt/dotfiles..."
		mkdir -p /mnt/dotfiles
		cp -a /etc/dotfiles-src/. /mnt/dotfiles/

		# Install
		echo "Running nixos-install..."
		nixos-install --flake /mnt/dotfiles#claude-vm --no-root-passwd --show-trace

		echo "=== Installation complete! Shutting down... ==="
		${pkgs.systemd}/bin/systemctl poweroff
	'';
in
{
	imports = [
		"${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
	];

	# Serial console for -nographic QEMU
	boot.kernelParams = [ "console=ttyS0,115200n8" ];
	boot.loader.timeout = lib.mkForce 5;

	environment.etc."dotfiles-src".source = rootPath;

	environment.systemPackages = [ install-claude-vm ];

	# Auto-run installer on boot
	systemd.services.auto-install = {
		description = "Automatic claude-vm installation";
		after = [ "multi-user.target" ];
		wantedBy = [ "multi-user.target" ];
		path = with pkgs; [ nix nixos-install-tools util-linux coreutils git curl wget binutils e2fsprogs dosfstools parted ];
		serviceConfig = {
			Type = "oneshot";
			ExecStart = "${install-claude-vm}/bin/install-claude-vm";
			StandardOutput = "journal+console";
			StandardError = "journal+console";
		};
	};
}
