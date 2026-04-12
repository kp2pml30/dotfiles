{ lib, ... }:
{
	imports = [
		./common.nix
	];

	boot.initrd.availableKernelModules = [
		"virtio_pci"
		"virtio_blk"
		"virtio_net"
		"virtio_balloon"
		"virtio_scsi"
		"xhci_pci"
		"ahci"
		"usbhid"
	];

	boot.kernelParams = [ "console=ttyS0,115200n8" ];
	boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
	boot.loader.grub = {
		enable = true;
		device = "/dev/vda";
		extraConfig = ''
			serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
			terminal_input serial console
			terminal_output serial console
		'';
	};

	fileSystems."/" = {
		device = "/dev/disk/by-label/nixos";
		fsType = "ext4";
	};

	services.qemuGuest.enable = true;

	networking = {
		hostName = "claude-vm";
		useDHCP = true;
	};
}
