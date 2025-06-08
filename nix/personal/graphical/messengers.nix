{ pkgs
, lib
, rootPath
, config
, system
, ...
}:
let
	cfg = config.kp2pml30;
	signalSuffix = if system == "x86_64-linux" then "amd64" else "arm64";
in lib.mkIf cfg.messengers.personal {
	users.users.${cfg.username}.packages = with pkgs; [
		discord-ptb
		telegram-desktop
		pkgs.signal-desktop
	];
}
