{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.messengers.work {
	users.users.${cfg.username}.packages = with pkgs; [
		slack
	];
}
