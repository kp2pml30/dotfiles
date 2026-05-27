{ pkgs
, inputs
, lib
, ...
}:
{
	imports = [ ./common.nix ];

	fileSystems."/" = {
		device = "/dev/disk/by-uuid/cad54483-783b-4210-9722-7355184866c3";
		fsType = "ext4";
	};

	fileSystems."/steam" = {
		device = "/dev/disk/by-uuid/7a3a64c3-66ae-4a11-962c-e5a831a17d91";
		fsType = "ext4";
	};

	fileSystems."/boot" = {
		device = "/dev/disk/by-uuid/0BBD-231D";
		fsType = "vfat";
		options = [ "fmask=0077" "dmask=0077" ];
	};

	swapDevices = [ { device = "/dev/disk/by-uuid/3231b9fd-4afe-41cf-a3ee-e71ceb774c1b"; } ];

	boot.kernelPackages = pkgs.linuxPackages_6_12;
	boot.kernelModules = [ "kvm-amd" ];

	# Razer Kiyo (1532:0e03) trips UVC probe control with -32 EPIPE.
	# 0x1 PROBE_MINMAX | 0x2 PROBE_EXTRAFIELDS | 0x20 FIX_BANDWIDTH
	# | 0x40 PROBE_DEF | 0x100 RESTORE_CTRLS_ON_INIT | 0x800 WAKE_AUTOSUSPEND
	boot.extraModprobeConfig = ''
		options uvcvideo quirks=0x963
	'';

	programs.nix-ld.enable = true;

	hardware.cpu.amd.updateMicrocode = true;

	hardware = {
		graphics = {
			enable = true;
			enable32Bit = true;
			extraPackages = with pkgs; [
			];

			extraPackages32 = with pkgs; [
			];
		};
	};

	networking = {
		useDHCP = lib.mkDefault true;
	};

	virtualisation.docker.enable = true;
}
