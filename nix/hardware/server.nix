{ pkgs
, inputs
, lib
, ...
}:
{
	imports = [
		./common.nix
	];

	boot.initrd.availableKernelModules = [
		"xhci_pci"
		"ehci_pci"
		"ahci"
		"usbhid"
		"usb_storage"
		"sd_mod"
		"virtio_balloon"
		"virtio_blk"
		"virtio_pci"
		"virtio_ring"
	];

	fileSystems."/" = {
		device = "/dev/disk/by-uuid/4a450f44-a611-4f12-9628-8d5da7cf0180";
		fsType = "ext4";
	};

	fileSystems."/boot" = {
		device = "/dev/disk/by-uuid/985D-9086";
		fsType = "vfat";
		options = [ "fmask=0077" "dmask=0077" ];
	};

	boot = {
		loader.grub = {
			enable = true;
			devices = [ "/dev/vda" ];
		};
	};

	services.qemuGuest.enable = true;

	networking = {
		hostName = "v168671";
		interfaces.ens3.ipv4.addresses = [ {
			prefixLength = 24;
			address = "185.121.233.63";
		} ];
		defaultGateway = "185.121.233.1";
		nameservers = [
			"1.1.1.1"
			"8.8.8.8"
		];
	};
}
