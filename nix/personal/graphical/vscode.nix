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
			package = pkgs.vscode.overrideAttrs (oldAttrs: {
				buildInputs = (oldAttrs.buildInputs or []) ++ [
					pkgs.curl
					pkgs.openssl
					pkgs.webkitgtk_4_1
					pkgs.libsoup_3
				];
			});
			mutableExtensionsDir = true; # unfortunately, vscode is pretty bad within nix
			profiles.default.userSettings = lib.importJSON("${rootPath}/vscode/settings.json");
		};
	};
}
