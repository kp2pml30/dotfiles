{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.vscode {
	home-manager.users.${cfg.username} = {
		programs.vscode = {
			enable = true;
			package = pkgs.vscode;
			mutableExtensionsDir = true; # unfortunately, vscode is pretty bad within nix
			profiles.default.userSettings = lib.importJSON("${rootPath}/vscode/settings.json");
		};
	};
}
