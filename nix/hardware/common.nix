{ pkgs
, inputs
, lib
, ...
}:
{
	options.kp2pml30.boot = {
		efiGrub = lib.mkEnableOption "";
	};

	imports = [
		./efiGrub.nix
	];

	config = {
		hardware.enableRedistributableFirmware = true;

		boot = {
			loader.efi.canTouchEfiVariables = true;

			initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci" "uas" "usbcore" ];
			initrd.kernelModules = [ ];
			extraModulePackages = [ ];
		};
	};
}
