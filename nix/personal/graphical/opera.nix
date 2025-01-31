{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.opera {
	home-manager.users.${cfg.username}.home = {
		packages = with pkgs; [
			(opera.override { proprietaryCodecs = true; })
		];
	};
}
