{ pkgs
, lib
, rootPath
, config
, user-groups-ids
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.gayming {
	programs.steam = {
		enable = true;
		remotePlay.openFirewall = true;
		dedicatedServer.openFirewall = false;
		localNetworkGameTransfers.openFirewall = true;
	};

	hardware.steam-hardware.enable = true;

	users.groups.steam-input.gid = user-groups-ids.gids.steam-input;
	users.users.${cfg.username}.extraGroups = [ "steam-input" ];

	# Switch 2 Pro Controller (057e:2069) — grant Steam uaccess so it can
	# open the hidraw directly. Tracks ValveSoftware/steam-for-linux#12585.
	services.udev.extraRules = ''
		SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2069", MODE="0660", GROUP="steam-input", TAG+="uaccess"
		KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2069", MODE="0660", GROUP="steam-input", TAG+="uaccess"
	'';

	# boot.kernelModules = [ "hid_nintendo" ];
	# disabled: hid-nintendo doesn't support Switch 2 Pro Controller (057e:2069);
	# probe fails with -110 (ETIMEDOUT) and no hidraw fallback is created,
	# so Steam can't see the controller. Leave it on hid-generic + Steam Beta.

	environment.systemPackages = with pkgs; [
		prismlauncher
	];
}
