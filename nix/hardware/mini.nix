{ pkgs
, inputs
, lib
, config
, ...
}:
{
	imports = [
		./common.nix
		# ./nvidia.nix
	];

	fileSystems."/" = {
		device = "/dev/disk/by-uuid/1ec7bbd6-cb83-427a-a901-d5fb7a4ef3ba";
		fsType = "ext4";
	};

	fileSystems."/boot" = {
		device = "/dev/disk/by-uuid/B19C-E7B1";
		fsType = "vfat";
		options = [ "fmask=0077" "dmask=0077" ];
	};

#	fileSystems."/mnt/d" = {
#		device = "/dev/sda1";
#		fsType = "exfat";
#		options = [
#			"users"
#			"exec"
#			"nofail"
#		];
#	};

	swapDevices = [ { device = "/dev/disk/by-uuid/c68daa9f-f165-4e23-8710-2aab0ad8d282"; } ];

	boot.kernelModules = [ "kvm-amd" ];

	environment.systemPackages = with pkgs; [
		exfat
	];

	hardware.cpu.amd.updateMicrocode = true;

	programs.nix-ld.enable = true;

	home-manager.users.${config.kp2pml30.username}.programs.git.extraConfig = {
		user.signingkey = "0xCD6528BAC23E3E34!";
		commit.gpgsign = true;
		tag.gpgSign = true;
	};

	hardware = {
		graphics = {
			enable = true;
			enable32Bit = true;
		};

		amdgpu.amdvlk = {
			enable = true;
			support32Bit.enable = true;
		};

		opengl.extraPackages = with pkgs; [
			amdvlk
		];

		opengl.extraPackages32 = with pkgs; [
			driversi686Linux.amdvlk
		];
	};

	networking = {
		useDHCP = lib.mkDefault true;
	};

	virtualisation.docker.enable = true;
}
