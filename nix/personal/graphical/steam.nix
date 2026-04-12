{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.steam {
	programs.steam = {
		enable = true;
		remotePlay.openFirewall = true;
		dedicatedServer.openFirewall = false;
		localNetworkGameTransfers.openFirewall = true;
	};

	hardware.steam-hardware.enable = true;
}
