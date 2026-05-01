{ pkgs
, inputs
, lib
, config
, ...
}:
{
	imports = [
		./common.nix
		./nvidia.nix
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

	fileSystems."/mnt/g" = {
		device = "/dev/disk/by-uuid/7878-8620";
		fsType = "exfat";
		options = [
			"users"
			"exec"
			"nofail"
		];
	};

	fileSystems."/mnt/d" = {
		device = "/dev/disk/by-uuid/C1E9-8BA0";
		fsType = "exfat";
		options = [
			"users"
			"exec"
			"nofail"
		];
	};

	fileSystems."/mnt/d/SteamLibrary/steamapps/compatdata" = {
		device = "/home/kp2pml30/.local/share/Steam/steamapps/compatdata-d";
		fsType = "none";
		options = [
			"bind"
			"nofail"
		];
	};

	swapDevices = [ { device = "/dev/disk/by-uuid/c68daa9f-f165-4e23-8710-2aab0ad8d282"; } ];

	boot.kernelParams = [ "pcie_aspm=off" ];
	boot.kernelModules = [ "kvm-amd" ];

	environment.systemPackages = with pkgs; [
		exfat
		pciutils
	];

	hardware.cpu.amd.updateMicrocode = true;

	programs.nix-ld.enable = true;

	home-manager.users.${config.kp2pml30.username}.programs.git.settings = {
		user.signingkey = "0x1739F9D8BA250D04!";
		commit.gpgsign = true;
		tag.gpgSign = true;
	};

	hardware = {
		graphics = {
			enable = true;
			enable32Bit = true;
			extraPackages = with pkgs; [
			];

			extraPackages32 = with pkgs; [
			];
		};


		nvidia.prime = {
			sync.enable = true;
			nvidiaBusId = "PCI:5:0:0";
			amdgpuBusId = "PCI:198:0:0";
		};
	};

	networking = {
		useDHCP = lib.mkDefault true;
		extraHosts = lib.concatMapStringsSep "\n" (domain: "0.0.0.0 ${domain}") [
			"overseauspider.yuanshen.com"
			"log-upload-os.hoyoverse.com"
			"log-upload-os.mihoyo.com"
			"dump.gamesafe.qq.com"

			"apm-log-upload-os.hoyoverse.com"
			"zzz-log-upload-os.hoyoverse.com"

			"log-upload.mihoyo.com"
			"devlog-upload.mihoyo.com"
			"uspider.yuanshen.com"
			"sg-public-data-api.hoyoverse.com"
			"hkrpg-log-upload-os.hoyoverse.com"
			"public-data-api.mihoyo.com"

			"prd-lender.cdp.internal.unity3d.com"
			"thind-prd-knob.data.ie.unity3d.com"
			"thind-gke-usc.prd.data.corp.unity3d.com"
			"cdp.cloud.unity3d.com"
			"remote-config-proxy-prd.uca.cloud.unity3d.com"

			"pc.crashsight.wetest.net"
		];
	};

	virtualisation.docker.enable = true;
}
