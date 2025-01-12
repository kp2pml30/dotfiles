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

		file.".config/opera/Default/Preferences" = { source = rootPath + "/home/.config/opera/Default/Preferences"; };
		file.".config/opera/Default/Bookmarks" = { source = rootPath + "/home/.config/opera/Default/Bookmarks"; };
	};
}
