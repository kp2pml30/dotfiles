{ pkgs
, inputs
, lib
, ...
}:
{
	hardware.enableRedistributableFirmware = true;

	boot = {
		loader.grub = {
			enable = true;
			devices = [ "nodev" ];
			efiSupport = true;
			useOSProber = true;
		};

		loader.efi.canTouchEfiVariables = true;

		initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci" ];
		initrd.kernelModules = [ ];
		extraModulePackages = [ ];
	};

	networking = {
		networkmanager.enable = true;
		useDHCP = lib.mkDefault true;
	};
}
