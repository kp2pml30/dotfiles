{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.messengers.personal {
	users.users.${cfg.username}.packages = with pkgs; [
		discord-ptb
		telegram-desktop
		signal-desktop
	];
}
