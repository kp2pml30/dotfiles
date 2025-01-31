{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.hardware.wireless {
	networking = {
		networkmanager.enable = false;
		wireless.iwd = {
			enable = true;
			settings = {
				Settings.AutoConnect = true;
			};
		};
	};

	hardware.bluetooth = {
		enable = true;
		powerOnBoot = true;
	};
}
