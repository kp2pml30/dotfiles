{ pkgs
, config
, lib
, inputs
, rootPath
, ...
}:
let
	cfg = config.kp2pml30.boot;
in lib.mkIf cfg.efiGrub {
	boot.loader.grub = {
		enable = true;
		devices = [ "nodev" ];
		efiSupport = true;
		useOSProber = true;
	};
}
