{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
	version = "123.0.5669.23";
	legacy-nixpkgs = import (builtins.fetchTarball {
		url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.11.tar.gz";
		sha256 = "1gx0hihb7kcddv5h0k7dysp2xhf1ny0aalxhjbpj2lmvj7h9g80a";
	}) {
		system = pkgs.system;
		config.allowUnfreePredicate = pkg:
			builtins.elem (pkgs.lib.getName pkg) [
				"vscode"
				"steam"
				"steam-run"
				"steam-original"
				"steam-unwrapped"
				"nvidia-x11"
				"nvidia-settings"
				"nvidia-persistenced"
				"opera"
				"discord"
				"slack"
				"anytype"
			];
	};
in lib.mkIf cfg.opera {
	home-manager.users.${cfg.username}.home = {
		packages = with legacy-nixpkgs; [
			((opera.override { proprietaryCodecs = true; }).overrideAttrs (finalAttrs: previousAttrs: {
				src = fetchurl {
					url = "https://get.geo.opera.com/pub/opera/desktop/${version}/linux/opera-stable_${version}_amd64.deb";
					hash = "sha256-j2kHdg8d60S9j3bLychjmH/cRAXHGIjOgGKqmNIhnHU=";
				};
			}))
		];
	};
}
