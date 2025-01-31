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

	boot.kernelModules = [ "kvm-amd" ];

	hardware.cpu.amd.updateMicrocode = true;

	hardware = {
		graphics = {
			enable = true;
			enable32Bit = true;
		};

		amdgpu.amdvlk = {
			enable = true;
			support32Bit.enable = true;
		};
	};

	networking = {
		useDHCP = lib.mkDefault true;
	};
}
