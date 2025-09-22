{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
	version = "122.0.5643.51";
in lib.mkIf cfg.opera {
	home-manager.users.${cfg.username}.home = {
		packages = with pkgs; [
			((opera.override { proprietaryCodecs = true; }).overrideAttrs (finalAttrs: previousAttrs: {
				src = fetchurl {
					url = "https://get.geo.opera.com/pub/opera/desktop/${version}/linux/opera-stable_${version}_amd64.deb";
					hash = "sha256-l/NG3UEI1MEu7yVte0wkxsMsIhpCsAT7292u/IsqUL0=";
				};
			}))
		];
	};
}
