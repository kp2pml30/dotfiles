{ config, pkgs, lib, modulesPath, user-groups-ids, ... }:
let
	uboot = pkgs.callPackage ./uboot.nix { };
in {
	imports = [
		"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
		../common.nix
	];

	# Declares & gates kp2pml30.hardware.wireless (-> wireless.nix / iwd).
	kp2pml30.hardware.wireless = true;

	nixpkgs.hostPlatform = "aarch64-linux";

	boot.kernelPackages = pkgs.linuxPackages_latest;
	# zfs is enabled by default in nixos-25.11's supportedFilesystems flag set
	# and doesn't build against linuxPackages_latest; we don't need it here.
	boot.supportedFilesystems.zfs = lib.mkForce false;

	hardware.deviceTree.enable = true;
	hardware.deviceTree.name = "rockchip/rk3576-nanopi-m5.dtb";

	boot.kernelParams = [
		"console=tty1"
		# Matches the rk3576 boot ROM / rkbin TPL/SPL fixed baud (UART0_M0).
		"console=ttyS0,1500000n8"
	];

	sdImage.firmwarePartitionOffset = 16;

	sdImage.postBuildCommands = ''
		dd if=${uboot}/u-boot-rockchip.bin \
		   of=$img \
		   bs=512 seek=64 \
		   conv=notrunc,fsync
	'';

	# hardware.enableRedistributableFirmware is set by ../common.nix.

	networking.useNetworkd = true;
	systemd.network.networks."10-eth" = {
		matchConfig.Name = "en* end*";
		networkConfig.DHCP = "yes";
	};
	# WiFi fallback: iwd associates (see ../wireless.nix), networkd does DHCP.
	systemd.network.networks."20-wlan" = {
		matchConfig.Name = "wl*";
		networkConfig.DHCP = "yes";
	};

	services.openssh = {
		enable = true;
		ports = [ 22 ];
		openFirewall = true;
		settings = {
			PasswordAuthentication = false;
			KbdInteractiveAuthentication = false;
			PermitRootLogin = lib.mkForce "no";
			AllowUsers = [ "kp2pml30" ];
		};
	};

	users.users.kp2pml30 = {
		isNormalUser = true;
		uid = user-groups-ids.uids.kp2pml30;
		extraGroups = [ "wheel" ];
		openssh.authorizedKeys.keys = [
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2dRBDECmIuKt+2B2q9cmFudKga+EzbD4pCX6x3JNLB kp2pml30@kp2pml30-personal-pc"
		];
		hashedPassword = "$6$UK6oHr2gPRYD4Rak$lgF.mYReC0jahNuI4kt0j/CsrajVzMprvp3HgjKwwsjYHU6/Ur9jfROXZbKhhpyCLRmnlCpWeRCbHEYO/jhIv/";
	};
	security.sudo.wheelNeedsPassword = false;
}
