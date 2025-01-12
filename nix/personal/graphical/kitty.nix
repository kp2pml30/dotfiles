{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.kitty {
	home-manager.users.${cfg.username}.programs.kitty = {
		enable = true;
		extraConfig = builtins.readFile (rootPath + "/home/.config/kitty/kitty.conf");
	};
}
